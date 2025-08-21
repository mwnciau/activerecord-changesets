module ActiveRecordChangesets
  class MissingParameters < StandardError; end

  def self.included(base)
    base.extend(ClassMethods)

    base.class_attribute :_changeset_classes, instance_accessor: false, default: {}
    base.private_class_method :_changeset_classes, :_changeset_classes=

    base.class_attribute :_changeset_mutex, instance_accessor: false, default: Mutex.new
    base.private_class_method :_changeset_mutex, :_changeset_mutex=

    base.const_set(:Changesets, Module.new)
  end

  module ClassMethods
    def changeset(name, &block)
      key = name.to_sym

      # Defer building the class until methods in the parent model are available
      _changeset_classes[key] = block

      # Define an instance method to convert an existing model into the changeset
      #
      # === Example
      #
      #   user = User.find(params[:id])
      #   changeset = user.change_email
      define_method(key) do |params = nil|
        changeset = becomes self.class.changeset_class(key)
        changeset.assign_attributes(params) unless params.nil?
        changeset.instance_variable_set(:"@parent_model", self)

        changeset
      end

      # Define a class-level convenience for the changeset
      #
      # === Example
      #
      #   changeset = User.register_user
      singleton_class.define_method(name) do |params = nil|
        new.send(name, params)
      end
    end

    def changeset_class(name)
      return self._changeset_classes[name] unless self._changeset_classes[name].is_a?(Proc)

      _changeset_mutex.synchronize do
        # Prevent rqce condition where two threads call changeset_class at the same time, both
        # observing a Proc and building two distinct classes
        return _changeset_classes[name] unless _changeset_classes[name].is_a?(Proc)

        _changeset_classes[name] = build_changeset_class(name)
      end
    end

    private def build_changeset_class(name)
      changeset_class = Class.new(self) do
        class_attribute :nested_changesets, instance_accessor: false, default: {}
        private_class_method :nested_changesets=

        class_attribute :permitted_attributes, instance_accessor: false, default: {}
        private_class_method :permitted_attributes=

        class << self
          delegate :model_name, to: :superclass

          def expect(*keys)
            keys.each do |key|
              self.permitted_attributes[key.to_sym] = {optional: false}
            end
          end

          def permit(*keys)
            keys.each do |key|
              self.permitted_attributes[key.to_sym] = {optional: true}
            end
          end

          def nested_changeset(association, changeset, optional: false, **options)
            association_key = association.to_sym
            changeset_key = changeset.to_sym

            self.nested_changesets[association_key] = changeset
            accepts_nested_attributes_for association_key, **options

            if optional
              permit :"#{association}_attributes"
            else
              expect :"#{association}_attributes"
            end

            # Change the association class to use the specified changeset class
            reflection = _reflections[association_key]
            changeset_class = reflection.klass.changeset_class(changeset_key)
            reflection.instance_variable_set(:@klass, changeset_class)
          end
        end

        # We overwrite assign_attributes to filter the attributes for all mass assignments
        def assign_attributes(new_attributes)
          unless new_attributes.respond_to?(:each_pair)
            raise ArgumentError, "When assigning attributes, you must pass a hash as an argument, #{new_attributes.class} passed."
          end

          new_attributes = new_attributes.to_unsafe_h if new_attributes.respond_to?(:to_unsafe_h)
          new_attributes.symbolize_keys! if new_attributes.respond_to?(:symbolize_keys!)

          # If the given Hash is wrapped in the model key, we extract it
          model_key = model_name.param_key.to_sym
          if new_attributes.has_key?(model_key) && new_attributes[model_key].respond_to?(:each_pair)
            new_attributes = new_attributes[model_key]
          end

          _assign_attributes(filter_permitted_attributes(new_attributes))
        end

        def filter_permitted_attributes(attributes)
          filtered_attributes = {}
          missing_attributes = []

          self.class.permitted_attributes.each do |key, config|
            if attributes.has_key?(key)
              filtered_attributes[key] = attributes[key]
            elsif  attributes.has_key?(key.to_s)
              filtered_attributes[key] = attributes[key.to_s]
            elsif !config[:optional]
              missing_attributes << key
            end
          end

          if missing_attributes.any?
            raise ActiveRecordChangesets::MissingParameters, "#{self.class.name}: Expected parameters were missing: #{missing_attributes.join(", ")}"
          end

          filtered_attributes
        end

        # When the changeset is persisted, notify the parent model
        def save(*)
          super(*)

          @parent_model.instance_variable_set(:@new_record, @new_record)
        end

        # When the changeset is persisted, notify the parent model
        def save!(*)
          super(*)

          @parent_model.instance_variable_set(:@new_record, @new_record)
        end
      end
      changeset_class.class_eval(&self._changeset_classes[name])

      # Give the anonymous class a name for clearer backtraces (e.g. Model::Changesets::CreateModel)
      const_get(:Changesets).const_set(name.to_s.camelcase, changeset_class)

      changeset_class
    end
  end
end
