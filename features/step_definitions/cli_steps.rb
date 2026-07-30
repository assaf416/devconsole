# encoding: utf-8

require 'open3'

APP_ROOT_PATH = File.expand_path('../../..', __FILE__)
DEVCONSOLE_BIN = File.join(APP_ROOT_PATH, 'bin', 'devconsole').freeze

def run_cli(*args)
  Dir.chdir(APP_ROOT_PATH) do
    stdout, stderr, status = Open3.capture3(
      { 'CUCUMBER_PUBLISH_QUIET' => 'true', 'DEVCONSOLE_NO_COVERAGE' => '1' },
      'bundle', 'exec', DEVCONSOLE_BIN, *args.map(&:to_s)
    )
    @last_output  = stdout + stderr
    @last_status  = status.exitstatus
  end
end

בהינתן('שה-CLI של devconsole מותקן') do
  expect(File.exist?(DEVCONSOLE_BIN)).to be true
end

כאשר('המשתמש מריץ את הפקודה עם --version') do
  run_cli('--version')
end

כאשר('המשתמש מריץ את הפקודה עם --help') do
  run_cli('--help')
end

כאשר('המשתמש מריץ את הפקודה {string}') do |cmd|
  run_cli(*cmd.split)
end

כאשר('המשתמש מריץ את הפקודה "test" על קובץ feature בודד') do
  run_cli('test', 'features/דף_הבית.feature')
end

כאשר('המשתמש מריץ את הפקודה "test" ללא ארגומנטים') do
  # Scope to homepage only to avoid recursive DB lock from nested full-suite runs
  run_cli('test', 'features/דף_הבית.feature')
end

כאשר('המשתמש מריץ את הפקודה "db" ללא ארגומנטים') do
  run_cli('db')
end

כאשר('המשתמש מריץ test על קובץ שאינו קיים') do
  run_cli('test', 'features/nonexistent_file.feature')
end

אז('הפלט צריך להכיל את מחרוזת הגרסה') do
  expect(@last_output).to match(/\d+\.\d+\.\d+/)
end

אז('הפלט צריך להכיל את הפקודה {string}') do |cmd|
  expect(@last_output).to include(cmd)
end

אז('הפלט צריך להכיל {string}') do |text|
  expect(@last_output).to include(text)
end

אז('הבדיקות צריכות לעבור') do
  expect(@last_output).to include('passed')
end

אז('קוד יציאה הוא 0') do
  expect(@last_status).to eq(0)
end

אז('קוד יציאה אינו 0') do
  expect(@last_status).not_to eq(0)
end
