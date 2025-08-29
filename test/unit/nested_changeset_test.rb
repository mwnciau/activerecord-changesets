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
    end

    Temping.create :room do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.belongs_to :house
      end

      changeset :valid_changeset do; end
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
end
