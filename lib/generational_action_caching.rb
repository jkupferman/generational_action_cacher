# GenerationalActionCaching
module GenerationalActionCaching
  mattr_accessor :app_name
  mattr_accessor :current_commit_hash

  def cache_action options={}
    key = generate_cache_key(request.request_uri)
    output = Rails.cache.read(key)
    if output
      render :text => output
      return
    else
      yield
      unless response.redirected_to || flash[:notice]
        Rails.cache.write(key,response.body, options)
      end
    end
  end

  def increment_generation_on_change
    unless request.get?
      Rails.cache.write(generation_cache_key,get_generation+1)
    end
  end

  # Include the commit hash when generating cache keys
  # By default check for svn or git repos
  def self.use_commit_hash vcs=["svn","git"]
    self.current_commit_hash = self.read_commit_hash(vcs)
  end

  private
  def generate_cache_key uri
    "#{app_name}/#{current_commit_hash}/#{get_generation}/#{uri}"
  end

  def get_generation
    # Cache the generation so it is only fetched once per request
    @generation ||= Rails.cache.fetch(generation_cache_key) { 1 }
  end

  def generation_cache_key
    "#{app_name}/GENERATION/"
  end

  # Include the commit hash in the cache key such that when code is
  # updated it does not fetch old data.
  # TODO: Add support for other VCS's like bzr
  def self.read_commit_hash vcs
    commit_hash = ""

    if vcs.kind_of?(Array)
      vcs.map! { |v| v.to_s }
    elsif !vcs.kind_of?(String)
      vcs = vcs.to_s
    end

    # Try to get the commit hash for a git repo
    commit_hash = `git log -1 --pretty=format:"%H" #{RAILS_ROOT} 2> /dev/null` if vcs.include?("git")
    # Try to get the commit hash for the svn repo
    commit_hash = `svn info #{RAILS_ROOT} 2> /dev/null | awk '/^Revision:/ { print $2 }'` if commit_hash.empty? && vcs.include?("svn")
    
    commit_hash.strip
  end

  # Dont set the commit hash by default, require that users explicitly ask for it
  self.current_commit_hash = ""

  # Use the folder name as the application name
  self.app_name = File.basename(RAILS_ROOT)
end
