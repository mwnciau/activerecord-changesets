# ActiveRecord Changesets

Add changeset functionality to ActiveRecord models. Changesets provide a way to create specialized model variants for different operations with controlled parameter validation and specific validations.

## Why Use Changesets?

Changesets help you:

- Create specialized model variants for different operations (create, update, etc.)
- Control which parameters are required or optional for each operation
- Apply specific validations to different operations
- Handle nested attributes with proper validation
- Work seamlessly with Rails' strong parameters

## Getting started

Add `rails-changesets` to your Rails project by adding it to your Gemfile:

```shell
gem install rails-changesets
```

Or using bundler:

```shell
bundle add rails-changesets
```

## Usage

To start using changesets, add it to your model:

```ruby
class ApplicationRecord < ActiveRecord::Base
  include ActiveRecordChangesets
end
```

### Defining Changesets

Define changesets for different operations on your model:

```ruby
class User < ApplicationRecord
  # Changeset for user creation
  changeset :create_user do
    # Required parameters
    expect :first_name, :last_name, :email, :password

    # Validations specific to this changeset
    validates :first_name, presence: true
    validates :last_name, presence: true
    validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
    validate :must_have_secure_password
  end

  # Changeset for updating user's name
  changeset :edit_name do
    # Optional parameter
    permit :first_name
    # Required parameter
    expect :last_name

    # Validations specific to this changeset
    validates :first_name, presence: true
    validates :last_name, presence: true
  end

  # Changeset for updating user's email
  changeset :edit_email do
    expect :email

    validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  end

  private

  def must_have_secure_password
    errors.add(:password, "can't be blank") unless self.password.present? && self.password.is_a?(String)
    errors.add(:password, "must be at least 10 characters") unless self.password.is_a?(String) && self.password.length >= 10
  end
end
```

### Using Changesets

#### Creating a new record with a changeset

```ruby
# Class-level method
changeset = User.create_user({
  first_name: "Bob", 
  last_name: "Ross", 
  email: "bob@example.com", 
  password: "password1234"
})

# Save the changeset to create the record
changeset.save!
```

#### Updating an existing record with a changeset

```ruby
user = User.find(params[:id])

# Instance-level method
changeset = user.edit_name({
  first_name: "Rob", 
  last_name: "Boss"
})

# Save the changeset to update the record
changeset.save!
```

#### Working with Rails Strong Parameters

Changesets work seamlessly with Rails' strong parameters:

```ruby
# In a controller
def create
  changeset = User.create_user(params)

  if changeset.save
    redirect_to user_path(changeset)
  else
    render :new
  end
end
```

### API Reference

#### Changeset Definition

```ruby
changeset :name do
  # Changeset configuration
end
```

#### Parameter Control

- `expect :param1, :param2, ...` - Define required parameters
- `permit :param1, :param2, ...` - Define optional parameters

#### Nested Changesets

For associations, you can define nested changesets:

```ruby
changeset :create_post do
  expect :title, :content

  # Define a nested changeset for the comments association
  # This will use the Comment model's :create_comment changeset
  nested_changeset :comments, :create_comment, optional: true
end
```

#### Error Handling

If required parameters are missing, a `ActiveRecordChangesets::MissingParameters` error will be raised:

```ruby
begin
  User.create_user({}) # Missing all required parameters
rescue ActiveRecordChangesets::MissingParameters => e
  puts e.message
  # => "User::Changesets::CreateUser: Expected parameters were missing: first_name, last_name, email, password"
end
```

## Benefits Over Traditional Approaches

Compared to traditional approaches like using `accepts_nested_attributes_for` or custom form objects:

1. **Cleaner Models**: Keep your models focused on business logic rather than form handling
2. **Explicit Parameter Requirements**: Clearly define which parameters are required or optional for each operation
3. **Operation-Specific Validations**: Apply validations only when they make sense for a specific operation
4. **Seamless Rails Integration**: Works with Rails' strong parameters and nested attributes
5. **Type Safety**: Changesets are actual model instances, so you get all the benefits of ActiveRecord
