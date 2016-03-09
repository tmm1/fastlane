def for_each_gem
  GEMS.each do |g|
    yield g if block_given?
  end
end

def rspec_json_from_log(gem_name, file)
  log = File.join(gem_name, file)
  file_text = File.read(log)
  log_json = JSON.parse(file_text)
end

def format_failures(failures)
  formatted_failures = []
  count = 1
  failures.each do |gem_name, failure_array|
    failure_array.each do |failure|
      file_path = failure["file_path"].sub(".", "")
      stack_frame = failure["exception"]["backtrace"].detect { |frame| frame.include?(file_path) }
      stack_frame_match = /#{gem_name}#{file_path}:(\d+).*/.match(stack_frame)
      code_line = get_line_from_file(stack_frame_match[1].to_i, "#{gem_name}#{file_path}").strip

      formatted_failure = count == 1 ? "\n" : ""
      formatted_failure += "#{count}) #{failure["full_description"]}\n"
      formatted_failure += "Failure/Error: #{code_line}\n".red
      formatted_failure += "#{failure["exception"]["message"]}".red
      formatted_failure += "# #{stack_frame_match[0]}\n".cyan
      formatted_failures << formatted_failure
      count += 1
    end
  end
  formatted_failures
end

def bundle_install
  cache_path = File.expand_path("/tmp/vendor/bundle")
  sh "bundle check --path='#{cache_path}' || bundle install --path='#{cache_path}' --jobs=4 --retry=3"
end

def get_line_from_file(line_number, file)
  File.open(file) do |io|
    io.each_with_index do |line, index|
      return line if line_number == index + 1
    end
  end
end

desc "Test all Fastlane Gems"
task :test_all do
  require 'bundler/setup'
  require 'colored'
  require 'fileutils'
  require 'json'

  exceptions = []
  repos_with_exceptions = []
  rspec_log_file = "rspec_logs.json"

  bundle_install
  for_each_gem do |repo|
    box "Testing #{repo}"
    Dir.chdir(repo) do
      FileUtils.rm_f(rspec_log_file)
      begin
        # From https://github.com/bundler/bundler/issues/1424#issuecomment-2123080
        # Since we nest bundle exec in bundle exec
        Bundler.with_clean_env do
          bundle_install
          sh "bundle exec rubocop"
          sh "bundle exec rspec --format documentation --format j --out #{rspec_log_file}"
        end
      rescue => ex
        puts "[[FAILURE]] with repo '#{repo}' due to\n\n#{ex}\n\n"
        exceptions << "#{repo}: #{ex}"
        repos_with_exceptions << repo
      end
    end
  end

  failed_tests_by_gem = {}
  example_count = 0
  duration = 0.0

  for_each_gem do |gem_name|
    failed_tests_by_gem[gem_name] = []
    log_json = rspec_json_from_log(gem_name, rspec_log_file)
    tests = log_json["examples"]
    summary = log_json["summary"]
    example_count += summary["example_count"]
    duration += summary["duration"]
    failed_tests_by_gem[gem_name] += tests.select { |r| r["status"] != "passed" }
  end

  failure_messages = failed_tests_by_gem.reduce([]) do |memo, (gem_name, failures)|
    memo += failures.map do |f|
      original_file_path = f["file_path"]
      file_path = original_file_path.sub(".", gem_name)
      "#{file_path}:#{f["line_number"]}".red + " # #{f["full_description"]}".cyan
    end
  end

  puts ("*" * 80).yellow
  box "Summary"
  puts "\nFinished in #{duration.round(3)} seconds"
  puts "#{example_count} examples, #{failure_messages.count} failure(s)".send(failure_messages.empty? ? :green : :red)

  unless failure_messages.empty?
    box "#{exceptions.count} repo(s) with test failures: " + repos_with_exceptions.join(", ")
    puts format_failures(failed_tests_by_gem)
    puts "Failed examples:"
    puts "#{failure_messages.join("\n")}\n"
  end

  if exceptions.empty?
    puts "Success 🚀".green
  else
    box "Exceptions"
    puts "\n" + exceptions.join("\n")
  end
end