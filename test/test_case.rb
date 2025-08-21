require "minitest/autorun"
require "minitest/reporters"
require "active_record_changesets"
require "temping"

class TestCase < Minitest::Test
  def teardown
    Temping.teardown
  end
end
