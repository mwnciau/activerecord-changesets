# ActiveRecord Changesets

Make your model updates explicit and predictable.

Instead of scattering validations, strong parameters, and business rules across controllers and models, changesets give you one clear pipeline for handling data before it touches the database.

* 🔍 Make model operations clear and intentional
* 🔒 Scope attribute filtering and validation per operation
* ✨ Reduce coupling between controllers and models

## Quick start

Install the gem:

```shell
bundle add activerecord-changesets
```

Use it in your model:

```ruby
class User < ApplicationRecord
  # Or include it in your ApplicationRecord class
  include ActiveRecordChangesets
  
  changeset :create_user do
    # Only allow the email and password fields to be changed
    expect :email, :password
    
    # Run validation rules specifically for this changeset
    validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
    validate :must_have_secure_password
  end
end

User.create_user(email: "bob@example.com", password: "password1234")
```

## Why use changesets?

### Reduce boilerplate and business logic in controllers

Validations are defined in our models, but we still need to use strong parameters in our controllers to filter incoming parameters. This approach leads to extra boilerplate and a tighter coupling between controllers and models. If you make a change to the model, you need to update the controller.

Changesets solve this problem by moving the behaviour of strong parameters to the model: each changeset defines which parameters are allowed to change. This means that controllers no longer need to know anything about model attributes - they can just focus on the HTTP request.

<details>
<summary>Show code example</summary>

```ruby
# Model
class User < ApplicationRecord
    changeset :create_user do
        expect :name
        validates :name, presence: true
    end
end

# Controller
class UsersController < ApplicationController
    def new
        render :new, locals: { changeset: User.create_user }
    end
    
    def create
        # Notice how the controller doesn't need to know about the model's attributes
        changeset = User.create_user(params)
        
        if changeset.save
            redirect_to changeset
        else
            render :new, locals: { changeset: changeset }, status: :unprocessable_content
        end
    end
end

# View
<%= form_with changeset do |f| %>
    <%= f.text_field :name %>
    <%= f.submit %>
<% end %>
```
</details>


### Prevent validation changes from causing unintended consequences

If you ever need to change the validation logic in your model, you may end up with unintended consequences for your existing data. For example, if you start validating that all users have a phone number, if you're not careful, an existing record without a phone number may be marked invalid when they go to change their password.

Changesets let you define validations that are specific to each operation, so you can be sure that your validation logic is only applied when it makes sense.

Although this is possible using contexts in vanilla Rails, it can be difficult to see which validations apply to which operations.

<details>
<summary>Show code example</summary>

```ruby
# Model
class User < ApplicationRecord
    changeset :edit_name do
        expect :name
        
        validates_name
    end
    
    changeset :edit_phone do
        expect :phone_number
        
        validates_phone_number
    end
    
    def self.validates_name
        validates :name, presence: true
    end
    
    def self.validates_phone_number
        validates :phone_number, presence: true
    end
end
```

Because the validations are scoped to the changeset, you won't get an unexpected phone number error when you try to change your name.
</details>

### Simplify nested attributes

Nested attributes are a common pattern in Rails, but it can be tricky to permit the right parameters using strong parameters. Nested changesets let you define a changeset for each association so that the changeset controls which parameters are allowed.

<details>
<summary>Show code example</summary>

```ruby
class User < ApplicationRecord
    has_many :accounts
    
    changeset :edit_user do
        expect :email
        validates :email, presence: true
        
        nested_changeset :accounts, :edit_account
    end
end

class Account < ApplicationRecord
    belongs_to :user
    
    changeset :edit_account do
        expect :name
        validates :name, presence: true
    end
end

def update
    changeset = @user.edit_user(params)
    changeset.save!
end
```
</details>

## Getting started

Install `activerecord-changesets` in your Rails project:

```ruby
# Gemfile
gem "activerecord-changesets"
```

Or using bundler:

```shell
bundle add activerecord-changesets
```

## Usage

To start using changesets, add it to your model:

```ruby
class ApplicationRecord < ActiveRecord::Base
  include ActiveRecordChangesets
end
```

### Defining Changesets

Use the class-level `changeset` method to define a changeset:

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

#### Automatical parameter unwrapping

If parameters are wrapped under the model parameter key (e.g., { user: { ... } }), they will be unwrapped automatically. The following two calls are equivalent:

```ruby
user.edit_email({user: {email: "..."}})
user.edit_email(email: "...")
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

Note: `nested_changeset` forwards any additional options to ActiveRecord's `accepts_nested_attributes_for` (e.g., `:allow_destroy`, `:limit`, `:update_only`, `:reject_if`). The `:optional` flag controls whether `[association]_attributes` is expected (required) or merely permitted for this changeset.

#### Configuration

These global settings can be overridden in a Rails initializer:

```ruby
# Whether to raise an error if unexpected parameters are passed to a changeset
# Defaults to true
ActiveRecordChangesets.strict_mode = false

# Parameter keys that are ignored when strict mode is enabled
# Defaults to [:authenticity_token, :_method]
ActiveRecordChangesets.ignored_attributes = [:authenticity_token, :_method, :utf8]
```

These options can also be overridden on a per-changeset basis:

```ruby
class User < ApplicationRecord
  include ActiveRecordChangesets

  changeset :register, strict: false, ignore: [:utf8, :commit] do
    expect :email, :password
    permit :name
  end
end
```

#### Error Handling

If required parameters are missing, an ActiveRecordChangesets::MissingParametersError will be raised:

```ruby
begin
  User.create_user({}) # Missing all required parameters
rescue ActiveRecordChangesets::MissingParametersError => e
  puts e.message
  # => "User::Changesets::CreateUser: Expected parameters were missing: first_name, last_name, email, password"
end
```

If unexpected parameters are provided while strict mode is enabled (globally or for a specific changeset), an ActiveRecordChangesets::StrictParametersError will be raised:

```ruby
begin
  User.register(email: "a@b.com", password: "secret", extra: "nope")
rescue ActiveRecordChangesets::StrictParametersError => e
  puts e.message
  # => "User::Changesets::Register: Unexpected parameters passed to changeset: extra"
end
```

If you reference a changeset that hasn't been defined, an ActiveRecordChangesets::UnknownChangeset will be raised:

```ruby
begin
  User.changeset_class(:does_not_exist)
rescue ActiveRecordChangesets::UnknownChangeset => e
  puts e.message
end
```
