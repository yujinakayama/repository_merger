# frozen_string_literal: true

# (Almost) Disable the truncation of object inspection output
RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 10_000
