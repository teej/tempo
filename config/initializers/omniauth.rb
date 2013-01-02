Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, GOOGLE['client_id'], GOOGLE['client_secret'], :scope => 'userinfo.email,userinfo.profile,https://mail.google.com' 
end