require "minitest/autorun"
require "minitest/reporters"
require "active_record_changesets"
require "temping"

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:",
)

class TestCase < Minitest::Test
  def teardown
    Temping.teardown
  end
end

class Object
  def dd
    abort "
      Debug output
      #{caller(1..1)&.first&.delete_prefix("/var/source/")}
      (#{self.class.name}):
      #{pretty_inspect}
    "
  end
end

