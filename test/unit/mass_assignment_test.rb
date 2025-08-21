require "test_case"
require "action_controller/metal/strong_parameters"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

class MassAssignmentTest < TestCase
  def setup
    # Create the first model
    Temping.create :user do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.string :email
        t.string :other
      end

      changeset :expected_changeset do
        expect :name, :email
      end

      changeset :permitted_changeset do
        permit :name, :email
      end

      changeset :mixed_changeset do
        expect :name
        permit :email
      end
    end
  end

  def test_expected_allows_assignment
    changeset = User.expected_changeset(name: "Bob", email: "bob@example.com")
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Bob", user.name
    assert_equal "bob@example.com", user.email
  end

  def test_expected_raises_on_missing
    error = assert_raises ActiveRecordChangesets::MissingParameters do
      User.expected_changeset({})
    end

    assert_equal "User::Changesets::ExpectedChangeset: Expected parameters were missing: name, email", error.message
  end

  def test_permitted_allows_assignment
    changeset = User.permitted_changeset(name: "Bob", email: "bob@example.com")
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Bob", user.name
    assert_equal "bob@example.com", user.email
  end

  def test_permitted_allows_missing
    user = User.new(name: "Bob", email: "bob@example.com")

    changeset = user.permitted_changeset({})
    changeset.save!

    assert_equal "Bob", user.name
    assert_equal "bob@example.com", user.email

    changeset = user.permitted_changeset({name: "Rob"})
    changeset.save!

    assert_equal "Rob", user.name
    assert_equal "bob@example.com", user.email

    changeset = user.permitted_changeset({email: "rob@example.com"})
    changeset.save!

    assert_equal "Rob", user.name
    assert_equal "rob@example.com", user.email
  end

  def test_mixed_allows_assignment
    changeset = User.mixed_changeset(name: "Bob", email: "bob@example.com")
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Bob", user.name
    assert_equal "bob@example.com", user.email
  end

  def test_mixed_allows_missing_email
    changeset = User.mixed_changeset(name: "Bob")
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Bob", user.name
    assert_nil user.email
  end

  def test_mixed_raises_on_missing_name
    error = assert_raises ActiveRecordChangesets::MissingParameters do
      User.mixed_changeset(email: "Bob")
    end

    assert_equal "User::Changesets::MixedChangeset: Expected parameters were missing: name", error.message
  end
end
