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

    changeset = cat.change_name(name: "Rob")
    changeset.save!

    assert_equal 1, Cat.count
    assert_equal "Bob", cat.name
    assert_equal "Rob", cat.reload.name
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

  def test_strict_with_ignored_attributes
    cat = Cat.create!(name: "Bob")

    changeset = cat.strict_change_name(name: "Rob", authenticity_token: "something", _method: "patch")
    changeset.save!

    assert_equal "Rob", cat.reload.name
  end

  def test_strict_with_ignored_string_attributes
    cat = Cat.create!(name: "Bob")

    changeset = cat.strict_change_name(name: "Rob", "authenticity_token" => "something", "_method" => "patch")
    changeset.save!

    assert_equal "Rob", cat.reload.name
  end

  def test_config_strict_mode
    ActiveRecordChangesets.strict_mode = true

    Temping.create :strict_mode_on do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
      end

      changeset :change_name do
        expect :name
      end
    end

    error = assert_raises ActiveRecordChangesets::StrictParametersError do
      StrictModeOn.change_name(name: "Rob", extra_attribute: "something")
    end

    assert_equal "StrictModeOn::Changesets::ChangeName: Unexpected parameters passed to changeset: extra_attribute", error.message
  ensure
    ActiveRecordChangesets.strict_mode = false
  end

  def test_config_ignored_params
    existing_ignored_attributes = ActiveRecordChangesets.ignored_attributes
    ActiveRecordChangesets.strict_mode = true
    ActiveRecordChangesets.ignored_attributes = [:extra_attribute]

    Temping.create :different_ignored do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
      end

      changeset :change_name do
        expect :name
      end
    end

    error = assert_raises ActiveRecordChangesets::StrictParametersError do
      DifferentIgnored.change_name(name: "Rob", extra_attribute: "something", authenticity_token: "something")
    end

    assert_equal "DifferentIgnored::Changesets::ChangeName: Unexpected parameters passed to changeset: authenticity_token", error.message
  ensure
    ActiveRecordChangesets.strict_mode = false
    ActiveRecordChangesets.ignored_attributes = existing_ignored_attributes
  end

  def test_config_ignored_params_are_used_when_expected
    existing_ignored_attributes = ActiveRecordChangesets.ignored_attributes
    ActiveRecordChangesets.strict_mode = true
    ActiveRecordChangesets.ignored_attributes = [:name]

    Temping.create :ignored_expected_params do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
      end

      changeset :change_name do
        expect :name
      end
    end

    model = IgnoredExpectedParam.create!(name: "Bob")

    changeset = model.change_name(name: "Rob")
    changeset.save!

    assert_equal "Rob", model.reload.name
  ensure
    ActiveRecordChangesets.strict_mode = false
    ActiveRecordChangesets.ignored_attributes = existing_ignored_attributes
  end
end
