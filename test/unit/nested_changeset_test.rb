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

      changeset :invalid_nested_changeset do
        expect :name
        validates :name, presence: true

        nested_changeset :rooms, :invalid_changeset
      end

      changeset :invalid_nested_association do
        expect :name
        validates :name, presence: true

        nested_changeset :invalid, :valid_changeset
      end

      changeset :strict_changeset, strict: true do
        expect :name
        nested_changeset :rooms, :valid_changeset, allow_destroy: true
      end
    end

    Temping.create :room do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.belongs_to :house
      end

      changeset :valid_changeset do
        expect :name
      end
    end
  end

  def test_unknown_association_raises
    error = assert_raises(ArgumentError) do
      House.invalid_nested_association
    end

    assert_equal "No association found for name `invalid'. Has it been defined yet?", error.message
  end

  def test_unknown_nested_changeset_raises
    error = assert_raises(ActiveRecordChangesets::UnknownChangeset) do
      House.invalid_nested_changeset
    end

    assert_equal "Unknown changeset for Room: invalid_changeset", error.message
  end

  def test_strict_nested_changeset_does_not_raise
    # Nested changesets use the :id and :_destroy attributes, which should not trigger errors in strict mode
    house = House.create!
    room_to_update = house.rooms.create!
    room_to_delete = house.rooms.create!

    assert_equal 1, House.count
    assert_equal 2, house.rooms.count

    house.strict_changeset(name: "Bob", rooms_attributes: [{id: room_to_update.id, name: "Red"}, {id: room_to_delete.id, name: "Blue", _destroy: true}]).save!

    assert_equal 1, House.count
    assert_equal 1, house.rooms.count
    assert_equal "Bob", house.reload.name
    assert_equal "Red", house.rooms.first.name
  end
end
