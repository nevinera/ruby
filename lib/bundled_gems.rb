module Gem::BUNDLED_GEMS
  SINCE = {
    "rexml" => "3.0.0",
    "rss" => "3.0.0",
    "webrick" => "3.0.0",
    "matrix" => "3.1.0",
    "net-ftp" => "3.1.0",
    "net-imap" => "3.1.0",
    "net-pop" => "3.1.0",
    "net-smtp" => "3.1.0",
    "prime" => "3.1.0",
    "abbrev" => "3.4.0",
    "base64" => "3.4.0",
    "bigdecimal" => "3.4.0",
    "csv" => "3.4.0",
    "drb" => "3.4.0",
    "getoptlong" => "3.4.0",
    "mutex_m" => "3.4.0",
    "nkf" => "3.4.0",
    "observer" => "3.4.0",
    "racc" => "3.4.0",
    "resolv-replace" => "3.4.0",
    "rinda" => "3.4.0",
    "syslog" => "3.4.0",
  }.freeze

  EXACT = {
    "abbrev" => true,
    "base64" => true,
    "bigdecimal" => true,
    "csv" => true,
    "drb" => true,
    "getoptlong" => true,
    "mutex_m" => true,
    "nkf" => true, "kconv" => "nkf",
    "observer" => true,
    "resolv-replace" => true,
    "rinda" => true,
    "syslog" => true,
  }.freeze

  PREFIXED = {
    "bigdecimal" => true,
    "csv" => true,
    "drb" => true,
    "rinda" => true,
    "syslog" => true,
  }.freeze

  WARNED = {}                   # unfrozen

  conf = ::RbConfig::CONFIG
  LIBDIR = (conf["rubylibdir"] + "/").freeze
  ARCHDIR = (conf["rubyarchdir"] + "/").freeze
  dlext = [conf["DLEXT"], "so"].uniq
  DLEXT = /\.#{Regexp.union(dlext)}\z/
  LIBEXT = /\.#{Regexp.union("rb", *dlext)}\z/

  def self.find_gem(path)
    if !path
      return
    elsif path.start_with?(ARCHDIR)
      n = path.delete_prefix(ARCHDIR).sub(DLEXT, "")
    elsif path.start_with?(LIBDIR)
      n = path.delete_prefix(LIBDIR).chomp(".rb")
    else
      return
    end
    EXACT[n] or PREFIXED[n = n[%r[\A[^/]+(?=/)]]] && n
  end

  def self.warning?(name, specs: nil)
    name = File.path(name) # name can be a feature name or a file path with String or Pathname
    return if specs.to_a.map(&:name).include?(name.sub(LIBEXT, ""))
    name = name.tr("/", "-")
    _t, path = $:.resolve_feature_path(name)
    return unless gem = find_gem(path)
    caller = caller_locations(3, 3).find {|c| c&.absolute_path}
    return if find_gem(caller&.absolute_path)
    name = name.sub(LIBEXT, "") # assume "foo.rb"/"foo.so" belongs to "foo" gem
    return if WARNED[name]
    WARNED[name] = true
    if gem == true
      gem = name
    elsif gem
      return if WARNED[gem]
      WARNED[gem] = true
      "#{name} is found in #{gem}"
    else
      return
    end + build_message(gem)
  end

  def self.build_message(gem)
    msg = " which #{RUBY_VERSION < SINCE[gem] ? "will no longer be" : "is not"} part of the default gems since Ruby #{SINCE[gem]}."

    if defined?(Bundler)
      msg += " Add #{gem} to your Gemfile or gemspec."
      # We detect the gem name from caller_locations. We need to skip 2 frames like:
      # lib/ruby/3.3.0+0/bundled_gems.rb:90:in `warning?'",
      # lib/ruby/3.3.0+0/bundler/rubygems_integration.rb:247:in `block (2 levels) in replace_require'",
      location = caller_locations(3,3)[0]&.path
      if File.file?(location) && !location.start_with?(Gem::BUNDLED_GEMS::LIBDIR)
        caller_gem = nil
        Gem.path.each do |path|
          if location =~ %r{#{path}/gems/([\w\-\.]+)}
            caller_gem = $1
            break
          end
        end
        if caller_gem
          msg += " Also contact author of #{caller_gem} to add #{gem} into its gemspec."
        end
      end
    else
      msg += " Install #{gem} from RubyGems."
    end

    msg
  end

  freeze
end

# for RubyGems without Bundler environment.
# If loading library is not part of the default gems and the bundled gems, warn it.
class LoadError
  def message
    if !defined?(Bundler) && Gem::BUNDLED_GEMS::SINCE[path] && !Gem::BUNDLED_GEMS::WARNED[path]
      warn path + Gem::BUNDLED_GEMS.build_message(path)
    end
    super
  end
end
