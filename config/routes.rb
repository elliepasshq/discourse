# frozen_string_literal: true

Elliepass::Engine.routes.draw do
  # Member verification
  get "/verify" => "verification#start"

  get "/verify/complete" => "verification#complete"

  post "/member/invalidate" => "member#invalidate"

  # Admin connection page
  get "/admin" => "admin#show"

  # Admin connection APIs/actions
  get "/admin/connection" => "admin#status"
  post "/admin/connection/test" => "admin#test_connection"

  post "/policy" => "policy#update"
end

Discourse::Application.routes.draw { mount ::Elliepass::Engine, at: "/elliepass" }
