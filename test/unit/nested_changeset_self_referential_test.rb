require "test_case"

class NestedChangesetSelfReferentialTest < TestCase
  def setup
    Temping.create :user do
      include ActiveRecordChangesets

      with_columns do |t|
        t.string :name
        t.integer :manager_id
      end

      belongs_to :manager, class_name: "User", optional: true

      changeset :create_with_manager do
        expect :name

        nested_changeset :manager, :create_user, optional: true
      end

      changeset :create_user do
        expect :name
      end
    end
  end

  def test_self_referential_nested_changeset
    changeset = User.create_with_manager(
      name: "Alice",
      manager_attributes: {name: "Bob"},
    )
    changeset.save!

    assert_equal 2, User.count
    alice = User.find_by(name: "Alice")
    bob = User.find_by(name: "Bob")
    assert_equal bob.id, alice.manager_id
  end
end
