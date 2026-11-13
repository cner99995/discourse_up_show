# frozen_string_literal: true

module DiscourseTrustLevelProgress
  class TrustLevelProgressController < ::ApplicationController
    before_action :ensure_logged_in

    def show
      locale = current_user.effective_locale || I18n.locale
      payload = I18n.with_locale(locale) { Requirements.new(current_user).as_json }

      render json: payload
    end
  end
end
