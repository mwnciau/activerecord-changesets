require "active_support/core_ext/module/attribute_accessors"

# ActiveRecordChangesets provides a lightweight DSL to build parameter-scoped
# "changeset" subclasses of your ActiveRecord models. These changeset classes
# restrict mass assignment to a declared set of attributes and can operate in a
# strict mode that rejects unexpected parameters. Changesets are built lazily
# and named under Model::Changesets::<Name> for clearer backtraces.
#
# Typical usage:
#   class User < ApplicationRecord
#     include ActiveRecordChangesets
#
#     changeset :register, strict: true do
#       expect :email, :password
#       permit :name
#     end
#
#     changeset :update_profile do
#       permit :name, :bio
#       nested_changeset :profile, :update, optional: true
#     end
#   end
#
#   user = User.register(email: "a@b.com", password: "secret")
#   user.save
module ActiveRecordChangesets
  # Base error for all gem-specific exceptions
  class Error < StandardError; end

  # Raised when required parameters are missing while building/assigning a changeset
  class MissingParametersError < Error; end

  # Raised when strict mode is enabled and unexpected parameters are provided
  class StrictParametersError < Error; end

  # Raised when requesting an undefined changeset
  class UnknownChangeset < Error; end

  # Global list of attribute keys that will be ignored when checking for extra
  # attributes in strict mode. Defaults to Rails form helpers params.
  # @return [Array<Symbol>]
  mattr_accessor :ignored_attributes, default: [:authenticity_token, :_method]

  # Global default for strict mode. If true, changesets will reject any
  # parameters not explicitly expected/permitted. Can be overridden per changeset.
  # @return [Boolean]
  mattr_accessor :strict_mode, default: true

  # Hook invoked when the module is included into an ActiveRecord model.
  # It installs internal state used to register and build changesets and defines
  # the Model::Changesets namespace for named anonymous classes.
  # @param base [Class] the including model class
  def self.included(base)
    base.extend(ClassMethods)

    base.class_attribute :_changesets, default: {}
    base.private_class_method :_changesets, :_changesets=

    base.class_attribute :_changeset_mutex, instance_accessor: false, default: Mutex.new
    base.private_class_method :_changeset_mutex, :_changeset_mutex=

    base.const_set(:Changesets, Module.new)
  end

  module ClassMethods
    # @!group Changeset DSL (class-level)

    # @!scope class
    # @!method nested_changeset(association, changeset, optional: false, **options)
    #   Declare a nested changeset for an association and wire up nested attributes handling.
    #   This makes "<association>_attributes" permitted or expected depending on `optional`,
    #   and configures `accepts_nested_attributes_for` on the association.
    #   @param association [Symbol, String] The association name (e.g., :profile)
    #   @param changeset [Symbol, String] The changeset name on the associated model (e.g., :update_profile)
    #   @param optional [Boolean] If true, parameters are optional; otherwise required
    #   @param options [Hash] Options forwarded to `accepts_nested_attributes_for`
    #   @option options [Boolean] :allow_destroy Whether to allow destroying nested records
    #   @option options [Integer] :limit Max number of associated records
    #   @option options [Boolean] :update_only Only update existing records
    #   @option options [Proc,Symbol] :reject_if A Proc or a Symbol pointing to a method that checks whether a record should be built for a certain attribute hash
    #   @see ActiveRecord::NestedAttributes::ClassMethods#accepts_nested_attributes_for

    # @!scope class
    # @!method expect(*parameter_keys)
    #   Declare required parameters for a changeset. If any are missing, building/assigning
    #   will raise an error describing the missing keys.
    #   @param parameter_keys [Array<Symbol>] Keys that must be present in changeset parameters

    # @!scope class
    # @!method permit(*parameter_keys)
    #   Declare optional parameters for this changeset. These are allowed but not required.
    #   @param parameter_keys [Array<Symbol>] Keys that may be present in changeset parameters

    # @!endgroup

    # Define a changeset for this model.
    #
    # Registers a lazily-built anonymous subclass that filters mass-assignment to
    # declared parameters. Also defines:
    # - an instance method with the same name that returns a changeset instance
    #   seeded from the model and optionally assigned with params
    # - a class method with the same name that instantiates a new model and
    #   returns its changeset
    #
    # @param name [Symbol, String] The changeset name (e.g., :register)
    # @param options [Hash] Options controlling behavior
    # @option options [Boolean] :strict Whether to enable strict parameter checking (defaults to ActiveRecordChangesets.strict_mode)
    # @option options [Array<Symbol>] :ignore Attribute keys to ignore when checking for extra params (defaults to ActiveRecordChangesets.ignored_attributes)
    # @yield DSL to declare expected/permitted attributes and nested changesets
    # @yieldparam self [Class] the generated changeset class
    # @return [void]
    # @example
    #   changeset :register, strict: true do
    #     expect :email, :password
    #     permit :name
    #   end
    def changeset(name, **options, &block)
      key = name.to_sym

      options.with_defaults!(strict: ActiveRecordChangesets.strict_mode, ignore: ActiveRecordChangesets.ignored_attributes)

      # Defer building the class until methods in the parent model are available
      _changesets[key] = {dsl_proc: block, options:}

      # Define an instance method to convert an existing model into the changeset
      #
      # === Example
      #
      #   user = User.find(params[:id])
      #   changeset = user.change_email
      define_method(key) do |params = nil|
        changeset = self.class.changeset_class(key).new
        changeset.instance_variable_set(:@attributes, @attributes.deep_dup)
        changeset.instance_variable_set(:@mutations_from_database, @mutations_from_database ||= nil)
        changeset.instance_variable_set(:@new_record, new_record?)
        changeset.instance_variable_set(:@destroyed, destroyed?)

        changeset.assign_attributes(params) unless params.nil?
        changeset.instance_variable_set(:@parent_model, self)

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

    # Resolve or build the concrete changeset class for the given name.
    # The class is built lazily and cached. Thread-safe via a mutex.
    # @param name [Symbol, String]
    # @return [Class] the generated changeset subclass
    # @raise [UnknownChangeset] if the name was never registered via `changeset`
    def changeset_class(name)
      raise UnknownChangeset, "Unknown changeset for #{self.name}: #{name}" unless _changesets.has_key?(name)

      return _changesets[name][:class] if _changesets[name][:class].present?

      _changeset_mutex.synchronize do
        # Prevent race condition where two threads call changeset_class at the same time, both
        # observing a Proc and building two distinct classes
        return _changesets[name][:class] if _changesets[name][:class].present?

        _changesets[name][:class] = build_changeset_class(name)
      end
    end

    # Build the anonymous changeset subclass and evaluate its DSL.
    # Gives the class a stable constant under Model::Changesets for better backtraces.
    # @api private
    # @param name [Symbol]
    # @return [Class]
    private def build_changeset_class(name)
      changeset_class = Class.new(self) do
        class_attribute :nested_changesets, instance_accessor: false, default: {}
        private_class_method :nested_changesets=

        class_attribute :permitted_attributes, instance_accessor: false, default: {}
        private_class_method :permitted_attributes=

        class_attribute :changeset_options, instance_accessor: false, default: {}

        class << self
          delegate :model_name, to: :superclass

          # Declare required parameter keys for this changeset.
          # @param keys [Array<Symbol,String>]
          # @return [void]
          def expect(*keys)
            keys.each do |key|
              permitted_attributes[key.to_sym] = {optional: false}
            end
          end

          # Declare optional parameter keys for this changeset.
          # @param keys [Array<Symbol,String>]
          # @return [void]
          def permit(*keys)
            keys.each do |key|
              permitted_attributes[key.to_sym] = {optional: true}
            end
          end

          # Declare a nested changeset for an association. Also wires up
          # accepts_nested_attributes_for and adds "<association>_attributes"
          # to permitted or expected parameters based on `optional`.
          # @param association [Symbol,String]
          # @param changeset [Symbol,String]
          # @param optional [Boolean]
          # @param options [Hash] forwarded to accepts_nested_attributes_for
          # @return [void]
          def nested_changeset(association, changeset, optional: false, **options)
            association_key = association.to_sym
            changeset_key = changeset.to_sym

            nested_changesets[association_key] = changeset
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
        # Accepts both ActionController::Parameters and plain Hash. If params are wrapped
        # under the model key (e.g., { user: {...} }), unwraps them. Applies strict/permit
        # rules and raises helpful errors when something is wrong.
        # @param new_attributes [Hash, ActionController::Parameters]
        # @raise [ArgumentError] if new_attributes is not a hash-like object
        # @raise [ActiveRecordChangesets::MissingParametersError] if required keys are missing
        # @raise [ActiveRecordChangesets::StrictParametersError] if strict mode and unexpected keys
        # @return [void]
        def assign_attributes(new_attributes)
          unless new_attributes.respond_to?(:each_pair)
            raise ArgumentError, "When assigning attributes, you must pass a Hash as an argument, #{new_attributes.class} passed."
          end

          new_attributes = new_attributes.to_unsafe_h if new_attributes.respond_to?(:to_unsafe_h)
          new_attributes = new_attributes.symbolize_keys if new_attributes.respond_to?(:symbolize_keys!)

          # If the given Hash is wrapped in the model key, we extract it
          model_key = model_name.param_key.to_sym
          if new_attributes.has_key?(model_key) && new_attributes[model_key].respond_to?(:each_pair)
            new_attributes = new_attributes[model_key]
          end

          _assign_attributes(filter_permitted_attributes(new_attributes))
        end

        # Internal helper to pick only expected/permitted attributes and validate presence
        # of required keys. Optionally enforces strict mode rejecting unexpected keys.
        # @param attributes [Hash]
        # @return [Hash] a filtered attributes hash suitable for _assign_attributes
        # @raise [MissingParametersError] when required keys are missing
        # @raise [StrictParametersError] when extra keys are present in strict mode
        def filter_permitted_attributes(attributes)
          filtered_attributes = {}
          missing_attributes = []

          self.class.permitted_attributes.each do |key, config|
            if attributes.has_key?(key)
              filtered_attributes[key] = attributes[key]
            elsif attributes.has_key?(key.to_s)
              filtered_attributes[key] = attributes[key.to_s]
            elsif !config[:optional]
              missing_attributes << key
            end
          end

          if missing_attributes.any?
            raise ActiveRecordChangesets::MissingParametersError, "#{self.class.name}: Expected parameters were missing: #{missing_attributes.join(", ")}"
          end

          # If we have enabled strict mode, check for extra attributes. Perform a faster check
          # using count first before comparing keys.
          if self.class.changeset_options[:strict] && attributes.count > filtered_attributes.count
            extra_attributes = attributes.keys - filtered_attributes.keys - self.class.changeset_options[:ignore]

            if extra_attributes.any?
              raise ActiveRecordChangesets::StrictParametersError, "#{self.class.name}: Unexpected parameters passed to changeset: #{extra_attributes.join(", ")}"
            end
          end

          filtered_attributes
        end
      end
      changeset_class.changeset_options = _changesets[name][:options]
      changeset_class.class_eval(&_changesets[name][:dsl_proc])
      _changesets[name].delete :dsl_proc

      # Give the anonymous class a name for clearer backtraces (e.g. Model::Changesets::CreateModel)
      const_get(:Changesets).const_set(name.to_s.camelcase, changeset_class)

      changeset_class
    end
  end
end
