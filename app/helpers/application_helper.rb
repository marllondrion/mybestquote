module ApplicationHelper
  include Rails.application.routes.url_helpers

  def yes_no(value)
    value ? t("common.yes") : t("common.no")
  end

  def turbo_stream_redirect_to(url)
    turbo_stream.action(:redirect, nil, url: url)
  end
end
