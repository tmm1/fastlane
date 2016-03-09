GEMS = %w(fastlane fastlane_core deliver snapshot frameit pem sigh produce cert gym pilot credentials_manager spaceship scan supply watchbuild match screengrab)
RAILS = %w(boarding refresher enhancer)

#####################################################
# @!group Everything to be executed in the root folder containing all fastlane repos
#####################################################

desc 'Setup the fastlane development environment'
task :bootstrap do
  system('gem install bundler') unless system('which bundle')
  Rake::Task[:clone].invoke
  Rake::Task[:install].invoke

  box 'You are up and running'
end

desc 'Clones all the repositories. Use `bootstrap` if you want to clone + install all gems'
task :clone do
  (GEMS + RAILS).each do |repo|
    if File.directory? repo
      sh "cd #{repo} && git pull"
    else
      sh "git clone https://github.com/fastlane/#{repo}"
    end
  end
end

desc 'Run `bundle update` for all the gems.'
task :bundle do
  GEMS.each do |repo|
    sh "cd #{repo} && bundle update"
  end
end

desc 'Run `bundle update` and `rake install` for all the gems.'
task install: :bundle do
  GEMS.each do |repo|
    sh "cd #{repo} && rake install"
  end
end

desc 'Show the un-commited changes from all repos'
task :diff do
  (GEMS + RAILS).each do |repo|
    Dir.chdir(repo) do
      output = `git diff --stat` # not using `sh` as it gets you into its own view
      if (output || '').length > 0
        box repo
        puts output
      end
    end
  end
end

desc 'Pulls the latest changes from all the gems repos'
task :pull do
  sh 'git pull' # the countdown repo itself

  (GEMS + RAILS).each do |repo|
    sh "cd #{repo} && git pull"
  end
end

desc 'Fetches the latest rubocop config from the fastlane main repo'
task :fetch_rubocop do
  fl_path = './fastlane/.rubocop_general.yml'
  fail 'Could not find rubocop configuration in fastlane repository' unless File.exist?(fl_path)
  rubocop_file = File.read(fl_path)

  GEMS.each do |repo|
    next if repo == 'fastlane' # we don't want to overwrite the main repo's config

    path = File.join(repo, '.rubocop_general.yml')
    if File.exist?(path)
      # we only want to store the file for repos we use rubocop in
      if File.read(path) != rubocop_file
        File.write(path, rubocop_file)
        puts "+ Updated rubocop file #{path}"
      else
        puts "- File #{path} unchanged"
      end
    end

    File.write(File.join(repo, '.hound.yml'), File.read('./fastlane/.hound.yml'))
    unless %w(gym fastlane_core).include?(repo) # some repos need Mac OS
      File.write(File.join(repo, '.travis.yml'), File.read('./fastlane/.travis.yml'))
    end
  end
end

task :test_all do
  exceptions = []
  repos_with_exceptions = []
  log_file = "rspec_logs.json"
  require 'bundler/setup'
  require 'colored'
  require 'fileutils'
  require 'json'

  def bundle_install
    cache_path = File.expand_path("/tmp/vendor/bundle")
    sh "bundle check --path='#{cache_path}' || bundle install --path='#{cache_path}' --jobs=4 --retry=3"
  end

  bundle_install
  ["fastlane", "deliver"].each do |repo|
    box "Testing #{repo}"
    Dir.chdir(repo) do
      FileUtils.rm_f(log_file)
      begin
        # From https://github.com/bundler/bundler/issues/1424#issuecomment-2123080
        # Since we nest bundle exec in bundle exec
        Bundler.with_clean_env do
          bundle_install
          sh "bundle exec rubocop"
          sh "bundle exec rspec --format documentation --format j --out #{log_file}"
        end
      rescue => ex
        puts "[[FAILURE]] with repo '#{repo}' due to\n\n#{ex}\n\n"
        exceptions << "#{repo}: #{ex}"
        repos_with_exceptions << repo
      end
    end
  end

  failures = {}
  example_count = 0
  duration = 0.0

  ["fastlane", "deliver"].each do |gem_name|
    failures[gem_name] = []
    log = File.join(gem_name, log_file)
    file_text = File.read(log)
    log_json = JSON.parse(file_text)
    results = log_json["examples"]
    failures[gem_name] += results.select { |r| r["status"] == "failed" }
    summary = log_json["summary"]
    example_count += summary["example_count"]
    duration += summary["duration"]
  end

  failure_messages = failures.reduce([]) do |memo, (gem_name, failures)|
    memo += failures.map do |f|
      original_file_path = f["file_path"]
      file_path = original_file_path.sub(".", gem_name)
      "#{file_path}:#{f["line_number"]}".red + " # #{f["full_description"]}".cyan
    end
  end

  puts ("*" * 80).yellow
  box "#{exceptions.count} repo(s) with test failures: " + repos_with_exceptions.join(", ") unless failure_messages.empty?
  puts format_failures(failures)
  puts "\nSummary:\n"
  puts "Finished in #{duration.round(3)} seconds"
  puts "#{example_count} examples, #{failure_messages.count} failure(s)\n".send(failure_messages.empty? ? :green : :red)
  puts "Failed examples:" unless failure_messages.empty?
  puts "#{failure_messages.join("\n")}\n" unless failure_messages.empty?

  if exceptions.empty?
    puts "Success 🚀".green
  else
    box "Exceptions"
    puts exceptions.join("\n")
  end

end

def format_failures(failures)
  printable = []
  failures.values.flatten.each_with_index do |failure, index|
    string = index == 0 ? "\n" : ""
    string += "#{index + 1}) #{failure["full_description"]}\n"
    string += "Failure/Error: \n".red
    string += "#{failure["exception"]["message"]}".red
    printable << string
  end
  printable
end

desc 'Fetch the latest rubocop config and apply&test it for all gems'
task rubocop: :fetch_rubocop do
  GEMS.each do |repo|
    path = File.join(repo, '.rubocop_general.yml')
    if File.exist?(path)
      begin
        sh "cd #{repo} && rubocop"
      rescue
        box "Validation for #{repo} failed"
      end
    else
      box "No rubocop for #{repo}..."
    end
  end
end

desc 'Print out the # of unreleased commits'
task :unreleased do
  GEMS.each do |repo|
    Dir.chdir(repo) do
      `git pull --tags`

      last_tag = `git describe --abbrev=0 --tags`.strip
      output = `git log #{last_tag}..HEAD --oneline`.strip

      if output.length > 0
        box "#{repo}: #{output.split("\n").count} Commits"
        output.split("\n").each do |line|
          puts "\t" + line.split(' ', 1).last # we don't care about the commit ID
        end
        puts "\nhttps://github.com/fastlane/#{repo}/compare/#{last_tag}...master"
      end
    end
  end
end

desc 'git push all the things'
task :push do
  (GEMS + RAILS).each do |repo|
    box "Pushing #{repo}"
    sh "cd #{repo} && git push origin master"
  end
end

desc 'enable lol commits for all repos'
task :lolcommits do
  (['.'] + GEMS + RAILS).each do |repo|
    box "Enabling lol commits for #{repo}"
    sh "cd #{repo} && lolcommits --enable"

    # We need to patch it to work with El Capitan
    path = File.join(repo, '.git', 'hooks', 'post-commit')
    content = File.read(path)
    content.gsub!('lolcommits --capture', 'lolcommits --capture --delay 4')
    File.write(path, content)
  end
end

desc 'enable auto push for all repos'
task :autopush do
  (['.'] + GEMS + RAILS).each do |repo|
    box "Enabling auto push for #{repo}"

    path = File.join(repo, '.git', 'hooks', 'post-commit')
    content = File.read(path)
    next if content.include?('git push')
    content += "\ngit push"
    File.write(path, content)
  end
end

task :rubygems_admins do
  names = ["KrauseFx", "ohayon", "samrobbins", "hemal", "asfalcone", "mpirri", "mfurtak", "i2amsam"]
  GEMS.each do |gem_name|
    names.each do |name|
      puts `gem owner #{gem_name} -a #{name}`
    end
  end
end

desc 'show repos with checked-out feature-branches'
task :features do
  (['.'] + GEMS + RAILS).each do |repo|
    branch = `cd #{repo} && git symbolic-ref HEAD 2>/dev/null | awk -F/ {'print $NF'}`
    puts "#{repo}\n  -> #{branch}" unless branch.include?('master')
  end
end

#####################################################
# @!group Helper Methods
#####################################################

def box(str)
  l = str.length + 4
  puts ''
  puts '=' * l
  puts '| ' + str + ' |'
  puts '=' * l
end
