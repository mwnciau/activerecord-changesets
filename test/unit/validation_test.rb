require "test_case"

class ValidationTest < TestCase
  def setup
    Temping.create :account do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.string :email
      end

      # 1) Add validation rules inside the changeset
      changeset :required_name do
        expect :name

        validates :name, presence: true
      end

      # 2) validate :symbol where symbol is an instance method on the parent model
      changeset :uppercase_name do
        expect :name
        validate :name_has_uppercase
      end

      def name_has_uppercase
        errors.add(:name, "must contain an uppercase letter") unless name.to_s.match(/[A-Z]/)
      end

      # 3) A parent class method that wraps `validates` and is used inside the changeset
      changeset :email_via_helper do
        expect :email

        validates_email
      end

      def self.validates_email
        validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
      end
    end
  end

  def test_validates_presence_inside_changeset
    # Missing expected param raises, so pass it as nil to hit the validator instead
    changeset = Account.required_name(name: nil)
    changeset.save

    refute changeset.valid?
    assert_equal 0, Account.count
    assert_equal({name: ["can't be blank"]}, changeset.errors.messages)

    changeset = Account.required_name(name: "Bob")
    changeset.save!

    assert_equal 1, Account.count
    assert_equal "Bob", Account.first.name
  end

  def test_validate_symbol_instance_method_on_parent
    # Provide expected param but fail custom validator
    changeset = Account.uppercase_name(name: "bob")
    changeset.save

    refute changeset.valid?
    assert_equal 0, Account.count
    assert_equal({name: ["must contain an uppercase letter"]}, changeset.errors.messages)

    # Now satisfy the custom validator
    changeset = Account.uppercase_name(name: "Bob")
    changeset.save!

    assert_equal 1, Account.count
    assert_equal "Bob", Account.first.name
  end

  def test_class_method_wrapping_validates_used_in_changeset
    # Bad email fails format validator (presence is satisfied)
    changeset = Account.email_via_helper(email: "not-an-email")
    changeset.save

    refute changeset.valid?
    assert_equal 0, Account.count
    assert_equal({email: ["is invalid"]}, changeset.errors.messages)

    # Good email passes
    changeset = Account.email_via_helper(email: "bob@example.com")
    changeset.save!

    assert_equal 1, Account.count
    assert_equal "bob@example.com", Account.first.email
  end

  def test_validations_are_isolated_per_changeset
    account = Account.new(email: "invalid email")

    # Ensure that email validation doesn't affect another changeset that doesn't include it
    # Here, `uppercase_name` does not validate email, so saving with invalid email is fine
    changeset = account.uppercase_name(name: "Bob")
    changeset.save!

    assert_equal 1, Account.count
    account = Account.first
    assert_equal "Bob", account.name
    # No email validation ran, so email can be invalid
    assert_equal "invalid email", account.email
  end
end
