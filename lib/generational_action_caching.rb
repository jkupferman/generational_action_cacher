# GenerationalActionCaching
module GenerationalActionCaching

  def self.included(base)
    base.extend(ClassMethods)
  end

  module InstanceMethods
    def cache_action
      return yield if self.class.not_current_environment

      key = self.class.generate_cache_key(request.request_uri)
      output = Rails.cache.read(key)
      if output
        render :text => output
        return
      else
        yield
        unless response.redirected_to || flash[:notice]
          Rails.cache.write(key,response.body,self.class.action_cache_config.cache_options)
        end
      end
    end

    def increment_generation_on_change
      return if self.class.not_current_environment
      unless request.get?
        Rails.cache.write(self.class.generational_cache_key,self.class.get_generation+1)
      end
    end
  end

  module ClassMethods
    def generational_action_cacher options={}
      include GenerationalActionCaching::InstanceMethods

      @gac_config = GenerationalActionCaching::Config.new(options)

      around_filter :cache_action, { :except => options[:cache_except], :only => options[:cache_only] }
      after_filter :increment_generation_on_change, { :except => options[:update_except], :only => options[:update_only] }
    end

    def generate_cache_key uri
      "#{@gac_config.app_name}/#{@gac_config.current_commit_hash}/#{get_generation}/#{uri}"
    end

    def action_cache_config
      @gac_config || self.superclass.instance_variable_get('@gac_config')
    end

    def generational_cache_key
      "#{@gac_config.app_name}/GENERATION/"
    end

    def get_generation
      # Cache the generation so it is only fetched from cache once per request
      @generation ||= Rails.cache.fetch(generational_cache_key) { 1 }
    end

    def not_current_environment
      (@gac_config.production_only && RAILS_ENV != "production")
    end
  end

  class Config
    SUPPORTED_VCS = ["svn","git"]

    class InvalidVersionControlSystem < Exception; end

    attr_accessor :app_name
    attr_accessor :current_commit_hash
    attr_accessor :cache_options
    attr_accessor :production_only
    
    def initialize(options={})
      # Dont set the commit hash by default
      self.current_commit_hash = ""

      if options[:use_commit_hash]
        self.current_commit_hash = read_commit_hash(options[:use_commit_hash] || SUPPORTED_VCS)
      end

      self.app_name = options[:app_name].to_s

      # If an application name is not provided then use the folder name
      self.app_name = File.basename(RAILS_ROOT) if self.app_name.empty?

      # Unless otherwise specified it runs in production/dev/test modes
      self.production_only = options[:production_only] || false

      self.cache_options = {}
      self.cache_options[:expires_in] = options[:expires_in] if options[:expires_in]
    end

    # Include the commit hash in the cache key such that when code is
    # updated it does not fetch old data.
    # TODO: Add support for other VCS's like bzr
    # TODO: This will only work on *nix systems, make this Windows friendly
    def read_commit_hash vcs
      commit_hash = ""

      if vcs.kind_of?(Array)
        vcs.map! { |v| v.to_s }
      elsif !vcs.kind_of?(String)
        vcs = vcs.to_s
      end

      vcs.each { |v| raise InvalidVersionControlSystem if !SUPPORTED_VCS.include?(v) }

      # Try to get the commit hash for a git repo
      commit_hash = `git log -1 --pretty=format:"%H" #{RAILS_ROOT} 2> /dev/null` if vcs.include?("git")
      # Try to get the commit hash for the svn repo
      commit_hash = `svn info #{RAILS_ROOT} 2> /dev/null | awk '/^Revision:/ { print $2 }'` if commit_hash.empty? && vcs.include?("svn")
      
      commit_hash.strip
    end
  end
end
