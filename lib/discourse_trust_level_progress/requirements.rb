# frozen_string_literal: true

module DiscourseTrustLevelProgress
  # Builds a localized, per-user gap report for the next trust level.
  # TL0/TL1 use the tl1_requires_* / tl2_requires_* site settings.
  # TL2 uses core's TrustLevel3Requirements so the rolling window numbers match
  # what the background job actually evaluates.
  class Requirements
    def initialize(user)
      @user = user
      @stat = user.user_stat
    end

    def as_json(*)
      case @user.trust_level
      when 0
        level_payload(1, "tl1", tl1_items)
      when 1
        level_payload(2, "tl2", tl2_items)
      when 2
        tl3_payload(maintenance: false)
      when 3
        tl3_payload(maintenance: true)
      else
        max_payload
      end
    end

    private

    def level_payload(target, mode, items)
      remaining = items.count { |i| !i[:met] }

      {
        mode: mode,
        current_trust_level: @user.trust_level,
        target_trust_level: target,
        title: t("title", current: @user.trust_level, target: target),
        subtitle: t("subtitle_level", target: target),
        summary: remaining.zero? ? t("summary_met") : t("summary_remaining", count: remaining),
        summary_state: remaining.zero? ? "met" : "pending",
        alerts: locked? ? [alert("info", t("alerts.locked"))] : [],
        footnote: t("footnote"),
        items: items,
      }
    end

    def max_payload
      {
        mode: "max",
        current_trust_level: @user.trust_level,
        target_trust_level: nil,
        title: t("title_max"),
        subtitle: t("subtitle_max"),
        summary: t("summary_max"),
        summary_state: "met",
        alerts: [],
        footnote: t("footnote"),
        time_period_days: nil,
        items: [],
      }
    end

    def tl1_items
      [
        min_item("topics_entered", @stat.topics_entered, SiteSetting.tl1_requires_topics_entered),
        min_item("posts_read", @stat.posts_read_count, SiteSetting.tl1_requires_read_posts),
        min_item(
          "time_read",
          @stat.time_read / 60,
          SiteSetting.tl1_requires_time_spent_mins,
          "minutes",
        ),
        min_item(
          "account_age",
          account_age_minutes,
          SiteSetting.tl1_requires_time_spent_mins,
          "minutes",
        ),
      ]
    end

    def tl2_items
      [
        min_item("days_visited", @stat.days_visited, SiteSetting.tl2_requires_days_visited, "days"),
        min_item(
          "topics_entered",
          @stat.topics_entered,
          SiteSetting.tl2_requires_topics_entered,
        ),
        min_item("posts_read", @stat.posts_read_count, SiteSetting.tl2_requires_read_posts),
        min_item(
          "time_read",
          @stat.time_read / 60,
          SiteSetting.tl2_requires_time_spent_mins,
          "minutes",
        ),
        min_item(
          "account_age",
          account_age_minutes,
          SiteSetting.tl2_requires_time_spent_mins,
          "minutes",
        ),
        min_item("likes_given", @stat.likes_given, SiteSetting.tl2_requires_likes_given),
        min_item("likes_received", @stat.likes_received, SiteSetting.tl2_requires_likes_received),
        min_item(
          "topic_reply_count",
          @stat.calc_topic_reply_count!,
          SiteSetting.tl2_requires_topic_reply_count,
        ),
      ]
    end

    def account_age_minutes
      ((Time.current - @user.created_at) / 60).floor
    end

    def tl3_payload(maintenance:)
      req = TrustLevel3Requirements.new(@user)
      days = req.time_period
      items = tl3_items(req, days, maintenance)
      failed = items.count { |i| !i[:met] }
      lost = req.requirements_lost?

      alerts = []
      alerts << alert("warn", t("alerts.grace_period")) if req.on_grace_period
      alerts << alert("danger", t("alerts.requirements_lost")) if maintenance && lost
      alerts << alert("danger", t("alerts.suspended")) if @user.suspended?
      alerts << alert("danger", t("alerts.silenced")) if @user.silenced?
      alerts << alert("info", t("alerts.locked")) if req.trust_level_locked

      if maintenance
        summary = lost ? t("summary_maintenance_lost", count: failed) : t("summary_maintenance_ok")
        state = lost ? "risk" : "met"
      elsif req.requirements_met?
        summary = t("summary_met")
        state = "met"
      else
        summary = t("summary_remaining", count: failed)
        state = "pending"
      end

      title =
        if maintenance
          t("title_maintenance", level: @user.trust_level)
        else
          t("title", current: @user.trust_level, target: 3)
        end

      {
        mode: maintenance ? "tl3_maintenance" : "tl3",
        current_trust_level: @user.trust_level,
        target_trust_level: 3,
        title: title,
        subtitle: maintenance ? t("subtitle_max") : t("subtitle_tl3", days: days),
        summary: summary,
        summary_state: state,
        alerts: alerts,
        footnote: t("footnote"),
        time_period_days: days,
        items: items,
      }
    end

    def tl3_items(req, days, maintenance)
      hint = t("hint_site_share", days: days)

      items = [
        min_item("days_visited", req.days_visited, req.min_days_visited, "days"),
        min_item("topics_replied_to", req.num_topics_replied_to, req.min_topics_replied_to),
        min_item("topics_viewed", req.topics_viewed, req.min_topics_viewed, hint: hint),
        min_item("posts_read", req.posts_read, req.min_posts_read, hint: hint),
        min_item(
          "topics_viewed_all_time",
          req.topics_viewed_all_time,
          req.min_topics_viewed_all_time,
        ),
        min_item("posts_read_all_time", req.posts_read_all_time, req.min_posts_read_all_time),
        min_item("likes_given", req.num_likes_given, req.min_likes_given),
        min_item("likes_received", req.num_likes_received, req.min_likes_received),
        min_item(
          "likes_received_users",
          req.num_likes_received_users,
          req.min_likes_received_users,
        ),
        min_item(
          "likes_received_days",
          req.num_likes_received_days,
          req.min_likes_received_days,
          "days",
        ),
        max_item("flagged_posts", req.num_flagged_posts, req.max_flagged_posts),
        max_item("flagged_by_users", req.num_flagged_by_users, req.max_flagged_by_users),
        max_item("penalties", req.penalty_counts.total, 0),
      ]

      # When retaining TL3, only show what is actually at risk; the full list
      # would be noise for a user who is comfortably above every threshold.
      maintenance ? items.reject { |i| i[:met] } : items
    end

    def min_item(key, value, required, unit = "count", hint: nil)
      value = value.to_i
      required = required.to_i
      percent =
        if required <= 0
          100
        else
          [[(value * 100.0 / required).floor, 100].min, 0].max
        end

      {
        key: key,
        label: t("requirements.#{key}"),
        value_text: format_value(value, unit),
        required_text: format_value(required, unit),
        percent: percent,
        met: value >= required,
        hint: hint,
      }
    end

    def max_item(key, value, limit, unit = "count")
      value = value.to_i
      limit = limit.to_i

      {
        key: key,
        label: t("requirements.#{key}"),
        value_text: format_value(value, unit),
        required_text: "≤ #{format_value(limit, unit)}",
        percent: value <= limit ? 100 : 0,
        met: value <= limit,
        hint: nil,
      }
    end

    def format_value(value, unit)
      case unit
      when "days"
        t("values.days", count: value)
      when "minutes"
        t("values.minutes", count: value)
      else
        value.to_s
      end
    end

    def locked?
      @user.manual_locked_trust_level.present?
    end

    def alert(level, text)
      { level: level, text: text }
    end

    def t(key, **opts)
      I18n.t("discourse_trust_level_progress.#{key}", **opts)
    end
  end
end
