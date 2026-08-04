#!/usr/bin/env ruby
# Creates/refreshes the MovieTrackerTests (hosted unit) and MovieTrackerUITests
# targets and syncs their source files. Re-runnable: safe to run after adding
# test files. Requires the `xcodeproj` gem.

require 'xcodeproj'
require 'json'
require 'securerandom'
require 'rexml/document'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'MovieTracker.xcodeproj')
APP_TARGET_NAME = 'Marquee'
APP_MODULE = 'Marquee'
TEAM = '5ZJB9DN7AQ'
DEPLOYMENT = '27.0'

UNIT = { name: 'MarqueeTests', type: :unit_test_bundle,
         bundle_id: 'com.ebarer.MarqueeTests', dir: 'MarqueeTests' }
UI   = { name: 'MarqueeUITests', type: :ui_test_bundle,
         bundle_id: 'com.ebarer.MarqueeUITests', dir: 'MarqueeUITests' }
# Legacy target names to clean up on rename.
LEGACY = %w[MovieTrackerTests MovieTrackerUITests]

project = Xcodeproj::Project.open(PROJECT_PATH)
app = project.targets.find { |t| t.name == APP_TARGET_NAME } or abort "App target not found"

def remove_target(project, name)
  project.targets.select { |t| t.name == name }.each do |t|
    t.build_configuration_list.build_configurations.each { |c| c.remove_from_project }
    t.build_configuration_list.remove_from_project
    t.remove_from_project
  end
  # Drop its product reference and group.
  project.products_group.files.select { |f| f.display_name == "#{name}.xctest" }.each(&:remove_from_project)
  if (g = project.main_group.children.find { |c| c.respond_to?(:display_name) && c.display_name == name })
    g.remove_from_project
  end
end

def swift_files(project, dir)
  abs = File.join(project.project_dir, dir)
  Dir.glob(File.join(abs, '**', '*.swift')).sort
end

def add_group_files(project, target, dir)
  group = project.main_group.new_group(dir, dir)
  swift_files(project, dir).each do |path|
    ref = group.new_file(path)
    target.add_file_references([ref])
  end
end

def common_settings(config, bundle_id)
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['DEVELOPMENT_TEAM'] = TEAM
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT
  s['SWIFT_VERSION'] = '5.0'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['MARKETING_VERSION'] = '1.0'
end

LEGACY.each { |name| remove_target(project, name) }

# --- Unit test target (hosted, so @testable import Marquee works) ---
remove_target(project, UNIT[:name])
unit = project.new_target(UNIT[:type], UNIT[:name], :ios, DEPLOYMENT, project.products_group, :swift)
unit.build_configurations.each do |c|
  common_settings(c, UNIT[:bundle_id])
  c.build_settings['TEST_HOST'] = "$(BUILT_PRODUCTS_DIR)/#{APP_MODULE}.app/#{APP_MODULE}"
  c.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
end
add_group_files(project, unit, UNIT[:dir])
unit.add_dependency(app)

# --- UI test target ---
remove_target(project, UI[:name])
ui = project.new_target(UI[:type], UI[:name], :ios, DEPLOYMENT, project.products_group, :swift)
ui.build_configurations.each do |c|
  common_settings(c, UI[:bundle_id])
  c.build_settings['TEST_TARGET_NAME'] = APP_TARGET_NAME
end
add_group_files(project, ui, UI[:dir])
ui.add_dependency(app)

project.save

# --- Test plan: run this target SERIALLY. The suites share global state
# (URLSession.shared stubs, MediaCacheStore.shared, on-disk store), so parallel
# execution races; serial is also the right model for the integration tests. ---
def container(uuid, name)
  { "containerPath" => "container:MovieTracker.xcodeproj", "identifier" => uuid, "name" => name }
end
plan = {
  "configurations" => [{ "id" => SecureRandom.uuid.upcase, "name" => "Configuration 1", "options" => {} }],
  "defaultOptions" => { "targetForVariableExpansion" => container(app.uuid, APP_TARGET_NAME) },
  "testTargets" => [
    { "parallelizable" => false, "target" => container(unit.uuid, UNIT[:name]) },
    { "parallelizable" => false, "target" => container(ui.uuid, UI[:name]) },
  ],
  "version" => 1,
}
plan_path = File.join(ROOT, "#{APP_TARGET_NAME}.xctestplan")
File.write(plan_path, JSON.pretty_generate(plan) + "\n")

# --- Point the scheme at the plan. With a default test plan, inline <Testables>
# are ignored, so drop them (they'd otherwise pile up stale refs across runs). ---
scheme_path = Xcodeproj::XCScheme.user_data_dir(PROJECT_PATH) + "#{APP_TARGET_NAME}.xcscheme"
scheme = File.exist?(scheme_path) ? Xcodeproj::XCScheme.new(scheme_path) : Xcodeproj::XCScheme.new
test_action = scheme.test_action.xml_element
test_action.delete_element('Testables')
test_action.delete_element('TestPlans')
plans = REXML::Element.new('TestPlans')
ref = plans.add_element('TestPlanReference')
ref.add_attribute('reference', "container:#{APP_TARGET_NAME}.xctestplan")
ref.add_attribute('default', 'YES')
test_action.add_element(plans)
scheme.save_as(PROJECT_PATH, APP_TARGET_NAME, false)

puts "Configured targets: #{project.targets.map(&:name).join(', ')}"
puts "Unit files: #{swift_files(project, UNIT[:dir]).size}, UI files: #{swift_files(project, UI[:dir]).size}"
