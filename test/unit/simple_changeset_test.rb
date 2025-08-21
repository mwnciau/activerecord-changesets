require "test_case"
require "action_controller/metal/strong_parameters"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

class ChangesetTest < TestCase
  def setup
    # Create the first model
    Temping.create :user do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :first_name
        t.string :last_name
        t.string :email
        t.string :password
        t.timestamps
      end

      changeset :create_user do
        expect :first_name, :last_name, :email, :password

        validate_name
        validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
        validate :must_have_secure_password
      end

      changeset :edit_name do
        permit :first_name
        expect :last_name

        validate_name
      end

      changeset :edit_email do
        expect :email

        validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
      end

      def self.validate_name
        validates :first_name, presence: true
        validates :last_name, presence: true
      end

      def must_have_secure_password
        errors.add(:password, "can't be blank") unless self.password.present? && self.password.is_a?(String)
        errors.add(:password, "must be at least 10 characters") unless self.password.is_a?(String) && self.password.length >= 10
      end
    end
  end

  def test_create_user
    changeset = User.create_user({first_name: "Bob", last_name: "Ross", email: "bob@example.com", password: "password1234"})
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Bob", user.first_name
    assert_equal "Ross", user.last_name
    assert_equal "bob@example.com", user.email
    assert_equal "password1234", user.password
  end

  def test_create_user_with_nested_attributes
    changeset = User.create_user({user: {first_name: "Bob", last_name: "Ross", email: "bob@example.com", password: "password1234"}})
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Bob", user.first_name
    assert_equal "Ross", user.last_name
    assert_equal "bob@example.com", user.email
    assert_equal "password1234", user.password
  end

  def test_create_user_with_strong_parameters
    params = ActionController::Parameters.new({user: {first_name: "Bob", last_name: "Ross", email: "bob@example.com", password: "password1234"}})

    changeset = User.create_user(params)
    changeset.save!

    assert_equal 1, User.count
    user = User.first
    assert_equal "Bob", user.first_name
    assert_equal "Ross", user.last_name
    assert_equal "bob@example.com", user.email
    assert_equal "password1234", user.password
  end

  def test_create_user_validates
    # These keys are all expected so we must pass them into the changeset
    changeset = User.create_user({first_name: nil, last_name: nil, email: nil, password: nil})
    changeset.save

    refute changeset.valid?
    assert_equal 0, User.count

    assert_equal({
      first_name: ["can't be blank"],
      last_name: ["can't be blank"],
      email: ["can't be blank", "is invalid"],
      password: ["can't be blank", "must be at least 10 characters"],
    }, changeset.errors.messages)
  end

  def test_create_user_missing_expected_parameters
    error = assert_raises(ActiveRecordChangesets::MissingParameters) do
      User.create_user({})
    end

    assert_equal "User::Changesets::CreateUser: Expected parameters were missing: first_name, last_name, email, password", error.message
  end

  def test_edit_name
    user = User.create(first_name: "Bob", last_name: "Ross", email: "bob@example.com", password: "password1234")

    changeset = user.edit_name({first_name: "Rob", last_name: "Boss"})
    changeset.save!

    assert_equal 1, User.count
    user.reload
    assert_equal "Rob", user.first_name
    assert_equal "Boss", user.last_name
  end

  def test_edit_name_missing_optional_parameter
    user = User.create(first_name: "Bob", last_name: "Ross", email: "bob@example.com", password: "password1234")

    changeset = user.edit_name({last_name: "Boss"})
    changeset.save!

    assert_equal 1, User.count
    user.reload
    assert_equal "Bob", user.first_name
    assert_equal "Boss", user.last_name
  end

  def test_edit_name_missing_expected_parameter
    user = User.create(first_name: "Bob", last_name: "Ross", email: "bob@example.com", password: "password1234")

    error = assert_raises(ActiveRecordChangesets::MissingParameters) do
      changeset = user.edit_name({first_name: "Boss"})
    end

    assert_equal "User::Changesets::EditName: Expected parameters were missing: last_name", error.message
  end

  def test_edit_name_does_not_have_other_changeset_validations
    # Create a record with invalid values for email and password
    user = User.create(first_name: "Bob", last_name: "Ross", email: "notanemail", password: "badpass")

    # The edit_name changeset doesn't specify validations for email and password so should still work
    changeset = user.edit_name({first_name: "Rob", last_name: "Boss"})
    changeset.save!

    assert_equal 1, User.count
    user.reload
    assert_equal "Rob", user.first_name
    assert_equal "Boss", user.last_name
  end
end
