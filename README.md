server-autorun
==============

Meteor smart package which provides a fully reactive server-side [Tracker.autorun](http://docs.meteor.com/#/full/tracker_autorun).
While Meteor does provide `Tracker.autorun` on the server, it is not officially supported
on the server and it has many limitations. For example, it cannot be used with fibers-enabled
synchronous ([blocking](https://github.com/peerlibrary/meteor-blocking)) code. This implementation
cooperates nicely with fibers and preserves Meteor environment variables where necessary, allowing
you to run any reactive code. Now you can really share the same code between client and server.

Adding this package to your [Meteor](http://www.meteor.com/) application will override
`Tracker.autorun` on the server with this implementation.

Server side only.

Acknowledgments
---------------

This package is based on the great work by [Diggory Blake](https://github.com/Diggsey/meteor-server-deps)
who made the first implementation.
