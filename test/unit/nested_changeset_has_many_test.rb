require "test_case"

class NestedChangesetHasManyTest < TestCase
  def setup
    Temping.create :library do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.string :location
      end

      has_many :books

      def self.validate_create
        expect :name
        validates :name, presence: true
      end

      changeset :create_library do
        validate_create
      end

      changeset :optional_has_many do
        validate_create
        nested_changeset :books, :create_book, optional: true, allow_destroy: true
      end

      changeset :required_has_many do
        validate_create
        nested_changeset :books, :create_book
      end
    end

    Temping.create :book do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :title
        t.belongs_to :library
      end

      belongs_to :library

      def self.validate_create
        expect :title
        validates :title, presence: true
      end

      changeset :create_book do
        validate_create
      end
    end
  end

  def test_has_many_required
    changeset = Library.required_has_many(name: "City Library", books_attributes: [
      {title: "Book A"},
      {title: "Book B"},
    ])
    changeset.save!

    assert_equal 1, Library.count
    library = Library.first
    assert_equal "City Library", library.name
    assert_equal 2, library.books.count
    assert_equal ["Book A", "Book B"], library.books.order(:title).pluck(:title)
  end

  def test_has_many_required_allows_empty_array
    changeset = Library.required_has_many(name: "City Library", books_attributes: [])
    changeset.save!

    assert_equal 1, Library.count
    library = Library.first
    assert_equal "City Library", library.name
    assert_equal 0, library.books.count
  end

  def test_has_many_required_raises_on_missing
    error = assert_raises(ActiveRecordChangesets::MissingParametersError) do
      Library.required_has_many(name: "City Library")
    end

    assert_equal "Library::Changesets::RequiredHasMany: Expected parameters were missing: books_attributes", error.message
  end

  def test_has_many_optional
    changeset = Library.optional_has_many(name: "City Library", books_attributes: [
      {title: "Book A"},
      {title: "Book B"},
    ])
    changeset.save!

    assert_equal 1, Library.count
    library = Library.first
    assert_equal "City Library", library.name
    assert_equal 2, library.books.count
    assert_equal ["Book A", "Book B"], library.books.order(:title).pluck(:title)
  end

  def test_has_many_optional_allows_missing_nested
    changeset = Library.optional_has_many(name: "City Library")
    changeset.save!

    assert_equal 1, Library.count
    library = Library.first
    assert_equal "City Library", library.name
    assert_equal 0, library.books.count
  end

  def test_has_many_optional_allows_empty_array
    changeset = Library.optional_has_many(name: "City Library", books_attributes: [])
    changeset.save!

    assert_equal 1, Library.count
    library = Library.first
    assert_equal "City Library", library.name
    assert_equal 0, library.books.count
  end

  def test_has_many_optional_raises_on_empty_nested_parameters
    error = assert_raises(ActiveRecordChangesets::MissingParametersError) do
      Library.optional_has_many(name: "City Library", books_attributes: [{}])
    end

    assert_equal "Book::Changesets::CreateBook: Expected parameters were missing: title", error.message
  end

  def test_has_many_edit_existing
    library = Library.create!(name: "City Library")
    book1 = library.books.create!(title: "Book A")

    changeset = library.optional_has_many(name: "City Library Updated", books_attributes: [
      {id: book1.id, title: "Book A2"},
      {title: "Book B"}
    ])
    changeset.save!

    assert_equal "City Library Updated", library.reload.name
    assert_equal ["Book A2", "Book B"], library.books.order(:title).pluck(:title)
  end

  def test_has_many_destroy_existing
    library = Library.create!(name: "City Library")
    book1 = library.books.create!(title: "Book A")
    book2 = library.books.create!(title: "Book B")

    assert_equal 2, library.books.count

    changeset = library.optional_has_many(name: "City Library Updated", books_attributes: [
      {id: book1.id, title: "Book A2"},
      {id: book2.id, title: "Book B", _destroy: true}
    ])
    changeset.save!

    assert_equal 1, library.books.count
    assert_equal ["Book A2"], library.books.order(:title).pluck(:title)
    assert_nil Book.find_by(id: book2.id)
  end
end
