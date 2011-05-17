require 'casclient'
require 'casclient/frameworks/rails/filter'
require 'dispatcher'

# Patches Redmine's ApplicationController dinamically. Prepends a CAS gatewaying
# filter.
module CAS
  module ApplicationControllerPatch
    def self.included(base) # :nodoc:
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Mark as unloadable so it is reloaded in development

        prepend_before_filter :cas_filter, :set_user_id
      end
    end

    module InstanceMethods
      def cas_filter
        if CAS::CONFIG['enabled'] and !['atom', 'xml', 'json'].include? request.format
          if params[:controller] != 'account'
            CASClient::Frameworks::Rails::GatewayFilter.filter(self)
          else
            CASClient::Frameworks::Rails::Filter.filter(self)
          end
        else
          true
        end
      end

      def set_user_id
        if CAS::CONFIG['enabled']
          user = User.find_by_login session[:cas_user]
          if user.nil? # New user
            @user = User.new(:language => Setting.default_language)
            @user.login = session[:cas_user]
            @user.mail = Digest::MD5.hexdigest(session[:cas_user]) + "@example.com"
            @user.firstname = "Firstname"
            @user.lastname = "Lastname"
            @user.admin = false
            @user.register
            @user.activate
            #@user.login = session[:auth_source_registration][:login]
            p "!!"
            p session
            #@user.auth_source_id = session[:auth_source_registration][:auth_source_id]
            p "!!"
            if @user.save
              session[:auth_source_registration] = nil
              p "!!"
              self.logged_user = @user
              p "!!"
              flash[:notice] = l(:notice_account_activated)
              redirect_to :controller => 'my', :action => 'account'
            end
            session[:auth_source_registration] = { :login => @user.login }
            #render :template => 'account/register_with_cas'
          elsif session[:user_id] != user.id
            session[:user_id] = user.id
            call_hook(:controller_account_success_authentication_after, { :user => user })
          end
        end
        true
      end
    end
  end
end

Dispatcher.to_prepare do
  require_dependency 'application_controller'
  ApplicationController.send(:include, CAS::ApplicationControllerPatch)
end
