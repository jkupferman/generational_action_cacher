= GenerationalActionCaching

== DESCRIPTION

GenerationalActionCaching allows applications to easily implement generational action caching. Most of the code is based on the "Accelerate your Rails Site with Automatic Generation-based Action Caching" presentation by Rod Cope of OpenLogic inc. For more information see the presentation available here: http://en.oreilly.com/oscon2009/public/schedule/detail/8417

== REQUIREMENTS

None

== INSTALLATION
script/plugin install git@github.com:jkupferman/GenerationalActionCaching.git

== SETUP
After installing the plugin, add the following to your application_controller.rb

if ENV["RAILS_ENV"] == "production"
include GenerationalActionCaching                                                
around_filter :cache_action                                                                       
after_filter :increment_generation_on_change
GenerationalActionCaching.use_commit_hash
end


== FAQ

1) What is generational caching?
It is a very simple but effective caching strategy for data. The application has a "generation" which is changed each time the application is changed. The generation is included in the cache key such that when it changes it will cause the next cache read to miss and regenerate the data. For example if the generation is currently 1 then all gets will hit the cache while the generation stays the same. When an update happens, the generation is incremented to 2. Thus the next time the data is read it will miss the cache and be regenerated. It should be noted that by default generational caching does not require data to be expired or deleted from the cache since when the generation is changed stale data is no longer accessed.

2) When is the generation changed?
By default the generation is changed on any non-get request (e.g. update, create, destroy). If there is a particular action that you do not want to change the cache key, skip the after filter on that action. For example if you dont want the update action to change the generation then add the following to your application_controller.rb.

skip_after_filter :increment_generation_on_change, :only => :update

Similarly, if you dont want the update action to change the generation of a specific controller, simply add the above line to that controller.

3)Why on earth are you using a commit hash?
The answer here is a bit subtle. Imagine you have an application which you start and then perform a get on the index action. It will start by initalizing the generation to 1 (since it was not in the cache before). Similarly, it will miss the cache for the index action since it was not in the cache before. After generating the page it will be written back into the cache. Next you terminate the application, make a code change to the index action, and then start it again. This time it will fetch the generation (which is still 1) and then it will do a lookup in the cache for the index page. Since the generation has not changed it would fetch the cached index page which was generated prior to the code change. This is probably not what you want and would cause the stale page to be displayed. In order to avoid this issue the current commit hash from the version control system is used to cause the key to change. 

4)What if I dont want to use a commit hash?
Simply remove the following line from your application_controller.rb
GenerationalActionCaching.use_commit_hash

5)Does the commit hash update automatically?
For performance reasons the commit hash is only fetched once when the module is loaded. If running in prodution classes are only loaded once and as a result commit hash will not update until the server (e.g. Mongrel) is restarted. 

5)What version control systems are supported?
SVN and git.

6)How do I specify which version control system I am using?
Simply add the name of the vcs you are using to the "use_commit_hash" line of your application controller, for example:
GenerationalActionCaching.use_commit_hash :svn
By default it will check for git and SVN, in that order.

7)This is awesome, how can I contribute?
While the plugin works as-is there are still quite a few improvements which could be made. First, adding support for other VCS systems (e.g. bzr) could help. Cleaning up the way the commit hashes are retrieved since it currently would only works on *nix based systems. Of course, adding tests would be greatly appreciated.

Copyright (c) 2009 [Jonathan Kupferman], released under the MIT license
