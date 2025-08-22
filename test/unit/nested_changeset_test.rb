require "test_case"

class NestedChangesetTest < TestCase
  def setup
    Temping.create :house do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.string :other
      end

      has_many :rooms

      def self.validate_create
        expect :name
        validates :name, presence: true
      end

      changeset :create_house do
        validate_create
      end

      changeset :optional_has_many do
        validate_create
        nested_changeset :rooms, :create_room, optional: true
      end

      changeset :required_has_many do
        validate_create
        nested_changeset :rooms, :create_room, optional: true
      end
    end

    Temping.create :room do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.string :other
        t.belongs_to :house
      end

      belongs_to :house

      def self.validate_create
        expect :name
        validates :name, presence: true
      end

      changeset :create_room do
        validate_create
      end

      changeset :optional_belongs_to do
        validate_create
        nested_changeset :house, :create_house, optional: true
      end

      changeset :required_belongs_to do
        validate_create
        nested_changeset :house, :create_house
      end

      changeset :nested_does_not_exist do
        validate_create
        nested_changeset :house, :invalid_changeeset
      end
    end
  end

  def test_unknown_nested_changeset_raises
    error = assert_raises(ActiveRecordChangesets::UnknownChangeset) do
      Room.nested_does_not_exist
    end

    assert_equal "Unknown changeset for House: invalid_changeeset", error.message
  end

  def test_belongs_to_required_with_parameters
    changeset = Room.required_belongs_to(name: "Kitchen", house_attributes: {name: "My House"})
    changeset.save!

    assert_equal 1, Room.count
    room = Room.first
    assert_equal "Kitchen", room.name

    assert room.house
    assert_equal "My House", room.house.name
  end

  def test_belongs_to_required_with_empty_nested_parameters
    error = assert_raises(ActiveRecordChangesets::MissingParameters) do
      Room.required_belongs_to(name: "Kitchen", house_attributes: {})
    end

    assert_equal "House::Changesets::CreateHouse: Expected parameters were missing: name", error.message
  end

  def test_belongs_to_required_raises_on_missing
    error = assert_raises(ActiveRecordChangesets::MissingParameters) do
      Room.required_belongs_to(name: "Kitchen")
    end

    assert_equal "Room::Changesets::RequiredBelongsTo: Expected parameters were missing: house_attributes", error.message
  end

  def test_belongs_to_optional
    changeset = Room.optional_belongs_to(name: "Kitchen", house_attributes: {name: "My House"})
    changeset.save!


    assert_equal 1, Room.count
    room = Room.first
    assert_equal "Kitchen", room.name

    assert room.house
    assert_equal "My House", room.house.name
  end

  def test_belongs_to_optional_allows_missing_nested_parameters
    changeset = Room.optional_belongs_to(name: "Kitchen")
    changeset.save!

    assert_equal 1, Room.count
    room = Room.first
    assert_equal "Kitchen", room.name

    assert_nil room.house
  end

  def test_belongs_to_optional_raises_on_empty_nested_parameters
    error = assert_raises(ActiveRecordChangesets::MissingParameters) do
      Room.optional_belongs_to(name: "Kitchen", house_attributes: {})
    end

    assert_equal "House::Changesets::CreateHouse: Expected parameters were missing: name", error.message
  end
end
