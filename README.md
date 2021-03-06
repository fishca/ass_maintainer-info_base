[![Gem Version](https://badge.fury.io/rb/ass_maintainer-info_base.svg)](https://badge.fury.io/rb/ass_maintainer-info_base)
# AssMaintainer::InfoBase

Gem for juggle with the [1C:Enterprise](http://1c.ru) application instances
(aka infobase or information base) as easy as possible.
Main thing of this gem is the class `AssMaintainer::InfoBase` which provides
features to do it.

In this gem defined two types of 1C application instance:

1. application deployed on a 1C:Enterprise application server aka *server infobase*
2. application deployed as a file aka *file infobase*

Class `AssMaintainer::InfoBase` implements both types of applications but using
difference mixins for each of them in constructor. Type of application,
detects per type of [connection string](https://github.com/leoniv/ass_launcher/blob/master/lib/ass_launcher/support/connection_string.rb).

## Restriction

Fully work with server infobse possible in Windows(Cygwin)
x86 Ruby only. Cause of this is in-process OLE server `V83.COMConnector` which
used for connect to 1C:Enterprise application server when require check for
infobase exist or get infobase sessions or drop infobase or etc. actions.

Furthermore, for fully working with server infobse require logging on a
1C:Enterprise application server as a central-server administrator and
as a cluster administrator.

Structure 1C:Enterprise application server is complex and confusing.
For more info about 1C:Enterprise server look 1C documentation.

Some examples for restrictions look in
[example](./test/ass_maintainer/examples_test.rb) defined as `Restrictions for`
spec

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ass_maintainer-info_base'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ass_maintainer-info_base

## Usage

### Small example:

```ruby
reqiure 'ass_maintainer/info_base'

# As infobase admin you should make backups of infobase

# Describe connection string
connection_string = 'File="infobase_path";'

# Get InfoBase instance
ib = AssMaintainer::InfoBase.new('infobase_name', connection_string)

# Dump data
ib.dump(dump_path)

# As 1C application developer you should make dump of infobase configuration

# Dump configuration
ib.cfg.dump(cf_dump_path)

# ... etc
```

### Destructive actions protection

On default all instance of `AssMaintainer::InfoBase` marked as `read_only`. If
infobase is `read_only` all destructive actions denied,
`MethodDenied` exception will be raised. For control it behavior uses
`read_only` parameter of constructor.

```ruby
ib = AssMaintainer::InfoBase.new('ib_name', 'File="path"')
ib.rm! :yes #raised AssMaintainer::InfoBase::MethodDenied

ib = AssMaintainer::InfoBase.new('ib_name', 'File="path"', false)
ib.rm! :yes #=> nil
```

### Define 1C:Enterprise version requirement

On default using last installed 1C:Enterprise version. But
`AssMaintainer::InfoBase` provides feature for define 1C:Enterprise version
manually.

Example for define 1C:Enterprise platform requirement

```ruby
# Define platform version for single instance
ib = AssMaintainer::InfoBase.new('ib_name', 'File="path"', platform_require: '~> 8.3.10.0')
ib.platform_require #=> "~> 8.3.10.0"

# Define platform verion for all instances
AssMaintainer::InfoBase.configure do |conf|
  conf.platform_require = '~> 8.3.9.0'
end

ib = AssMaintainer::InfoBase.new('ib_name', 'File="path"')
ib.platform_require #=> "~> 8.3.9.0"
```

### More examples

For more examples see [examples](./test/ass_maintainer/examples_test.rb)

## Test

For execute all tests require 1C:Enterprise platform installed.
Version defined in constant `PLATFORM_REQUIRE` in
[platform_require.rb](./test/test_helper/platform_require.rb)

For execute server infobase tests defined in
[examples](./test/ass_maintainer/examples_test.rb) require:
- running 1C:Enterprise application server. Version defined in `PLATFORM_REQUIRE`
- running data base(DBMS) server suitable for 1C:Enterprise.

On default, server infobase tests skipped. For execute server infobase tests
require to pass server parameters in `ENV[ESRV_ENV]` like this:

```
$export ESRV_ENV="--ragent user:pass@host:port \
  --rmngr user:pass@host:port \
  --dbms MSSQLServer \
  --dbsrv user:pass@localhost\\sqlexpress"
```

For running local 1C:Enterprise application server instance can use
[bin/runsrv](bin/runsrv):

    $bin/runsrv -h

But `runsrv` running 1C server only! DBMS server must be already running manually

Running all tests:

    $bundler exec rake test SIMPLECOV=YES

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. Run `bundle exec ass_maintainer-info_base` to use the gem in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/leoniv/ass_maintainer-info_base.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

