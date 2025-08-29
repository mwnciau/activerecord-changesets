require "test_case"

class NestedChangesetHabtmTest < TestCase
  def setup
    Temping.create :author do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
      end

      has_and_belongs_to_many :books

      def self.validate_create
        expect :name
        validates :name, presence: true
      end

      changeset :create_author do
        validate_create
      end

      changeset :optional_habtm do
        validate_create
        nested_changeset :books, :create_book, optional: true
      end

      changeset :required_habtm do
        validate_create
        nested_changeset :books, :create_book
      end
    end

    Temping.create :book do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :title
      end

      has_and_belongs_to_many :authors

      def self.validate_create
        expect :title
        validates :title, presence: true
      end

      changeset :create_book do
        validate_create
      end
    end

    Temping.create :authors_books do
      with_columns do |t|
        t.belongs_to :author
        t.belongs_to :book
      end
    end
  end

  def test_habtm_required
    changeset = Author.required_habtm(name: "A1", books_attributes: [{title: "B1"}, {title: "B2"}])
    changeset.save!

    assert_equal 1, Author.count
    assert_equal 2, Book.count
    author = Author.first
    assert_equal "A1", author.name
    assert_equal ["B1", "B2"], author.books.order(:title).pluck(:title)
  end

  def test_habtm_required_allows_empty_array
    changeset = Author.required_habtm(name: "A1", books_attributes: [])
    changeset.save!

    assert_equal 1, Author.count
    assert_equal 0, Book.count
    author = Author.first
    assert_equal "A1", author.name
  end

  def test_habtm_required_raises_on_missing
    error = assert_raises(ActiveRecordChangesets::MissingParametersError) do
      Author.required_habtm(name: "A1")
    end

    assert_equal "Author::Changesets::RequiredHabtm: Expected parameters were missing: books_attributes", error.message
  end

  def test_habtm_optional
    changeset = Author.optional_habtm(name: "A1")
    changeset.save!

    assert_equal 1, Author.count
    author = Author.first
    assert_equal "A1", author.name
    assert_equal 0, author.books.count
  end

  def test_habtm_optional_allows_empty_array
    changeset = Author.optional_habtm(name: "A1", books_attributes: [])
    changeset.save!

    assert_equal 1, Author.count
    assert_equal 0, Book.count
    author = Author.first
    assert_equal "A1", author.name
  end

  def test_habtm_optional_raises_on_empty_nested_parameters
    error = assert_raises(ActiveRecordChangesets::MissingParametersError) do
      Author.optional_habtm(name: "A1", books_attributes: [{}])
    end

    assert_equal "Book::Changesets::CreateBook: Expected parameters were missing: title", error.message
  end
end
