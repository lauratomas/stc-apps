

class IndexController < ApplicationController
  # Check authentication with CAS login
  before_filter CASClient::Frameworks::Rails::Filter
  before_filter :chooser

  def index
#    raise get_user.to_yaml
#    raise user.to_yaml
    raise session.to_yaml
  end
end
