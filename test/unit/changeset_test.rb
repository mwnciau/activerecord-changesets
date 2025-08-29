require "test_case"

class ChangesetTest < TestCase
  def setup
    Temping.create :cat do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
      end

      changeset :change_name do
        expect :name
      end

      changeset :strict_change_name, strict: true do
        expect :name
      end
    end
  end

  def test_original_model_is_unchanged
    cat = Cat.create!(name: "Bob")

    changeset = Cat.change_name(name: "Rob")
    changeset.save!

    assert_equal "Bob", cat.name
    assert_equal "Bob", cat.reload.name
  end

  def test_recover_original_model
    cat = Cat.create!(name: "Bob")

    changeset = cat.change_name(name: "Rob")
    changeset.save!

    cat = changeset.becomes Cat

    assert_equal Cat, cat.class
    assert_equal "Rob", cat.name
  end

  def test_strict_option
    cat = Cat.create!(name: "Bob")

    error = assert_raises ActiveRecordChangesets::StrictParametersError do
      cat.strict_change_name(name: "Rob", extra_attribute: "something")
    end

    assert_equal "Cat::Changesets::StrictChangeName: Unexpected parameters passed to changeset: extra_attribute", error.message
  end
end
