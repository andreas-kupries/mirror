
Commands to manage various forms of version control systems, for a local mirror

|Path		|Notes								|
|---		|---								|
|cron-job	|Cron job to run `get`						|
|cron-list	|Cron job to run `get-lists`					|
|get		|Run a step of the mirroring, or re-collect what to mirror	|
|get-lists	|Mirror a set of source forge mailing lists 	    		|
|new-mirror	|Make a local clone of a fossil repo, with exchange set up (*)	|
|vc-collect	|Scan a directory for repositories to mirror (**)    		|
|vc-fetch	|Mirror a specified set of repositories (**) 			|
|vc-gen-index	|Generate web index of mirrored repos				|
|vc-i		|Manage filesystem index files around the mirrored repos	|
|vc-take	|Query configuration for number of repos mirrored per step	|
|vc-take=	|Set number of repos to mirror per step	 	      		|
|Bzr/		|Tools around `bazaar`, currently none				|
|CVS/		|Tools around `cvs`, currently none				|
|Fossil/	|Tools around `fossil`	       					|
|Git/		|Tools around `git`						|
|Hg/		|Tools around `mercurial`					|
|SForge/	|Tools around `sourceforge` site, currently none		|
|SVN/		|Tools around `svn`	    	  	    			|
|inbound/	|Unsorted     							|

(*) Should be moved into `Fossil/`
(**) Currently supports `git` and `fossil`

A workspace using these commands can be found in `$HOME/Data/My/Mirror`.

See the README.md in that directory for more information.
