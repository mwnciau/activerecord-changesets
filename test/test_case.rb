require "minitest/autorun"
require "minitest/reporters"
require "active_record_changesets"
require "temping"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

class TestCase < Minitest::Test
  def teardown
    Temping.teardown
  end
end
