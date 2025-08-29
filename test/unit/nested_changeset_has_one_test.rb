require "test_case"

class NestedChangesetHasOneTest < TestCase
  def setup
    Temping.create :user do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
      end

      has_one :profile

      def self.validate_create
        expect :name
        validates :name, presence: true
      end

      changeset :create_user do
        validate_create
      end

      changeset :optional_has_one do
        validate_create
        nested_changeset :profile, :create_profile, optional: true
      end

      changeset :required_has_one do
        validate_create
        nested_changeset :profile, :create_profile
      end
    end

    Temping.create :profile do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.belongs_to :user
      end

      belongs_to :user

      def self.validate_create
        expect :name
        validates :name, presence: true
      end

      changeset :create_profile do
        validate_create
      end
    end
  end

  def test_has_one_required
    changeset = User.required_has_one(name: "Alice", profile_attributes: {name: "About Alice"})
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Alice", user.name

    assert user.profile
    assert_equal "About Alice", user.profile.name
  end

  def test_has_one_required_raises_on_missing
    error = assert_raises(ActiveRecordChangesets::MissingParametersError) do
      User.required_has_one(name: "Alice")
    end

    assert_equal "User::Changesets::RequiredHasOne: Expected parameters were missing: profile_attributes", error.message
  end

  def test_has_one_optional
    changeset = User.optional_has_one(name: "Alice")
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Alice", user.name

    assert_nil user.profile
  end

  def test_has_one_optional_raises_on_empty_nested_parameters
    error = assert_raises(ActiveRecordChangesets::MissingParametersError) do
      User.optional_has_one(name: "Alice", profile_attributes: {})
    end

    assert_equal "Profile::Changesets::CreateProfile: Expected parameters were missing: name", error.message
  end
end
