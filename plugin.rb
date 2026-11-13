# frozen_string_literal: true

# name: discourse-trust-level-progress
# about: Shows each user their own item-by-item progress toward the next trust level.
# version: 0.1.0
# authors: community
# url: https://example.com/discourse-trust-level-progress
# required_version: 3.2.0

enabled_site_setting :trust_level_progress_enabled

register_asset "stylesheets/trust-level-progress.scss"

after_initialize do
  # This Discourse build does not register plugin app/ directories with the
  # Zeitwerk autoloader, so load our classes explicitly instead of relying on
  # constant autoloading.
  require_relative "lib/discourse_trust_level_progress/requirements"
  require_relative "app/controllers/discourse_trust_level_progress/trust_level_progress_controller"

  Discourse::Application.routes.append do
    get "/trust-level-progress" => "discourse_trust_level_progress/trust_level_progress#show"
  end
end
