module AssMaintainer
  class InfoBase
    module ServerIb
      require 'ass_ole'
      module EnterpriseServers
        # @api private
        # Mixins
        module Support
          # Mixin for redirect +method_missing+ to +ole+ object
          module SendToOle
            def method_missing(m, *args)
              ole.send m, *args
            end
          end

          # Ole runtime mixin
          module OleRuntime
            # Close connection with 1C:Enterprise server
            def disconnect
              runtime_stop
            end

            # True if connected
            def connected?
              respond_to?(:ole_runtime_get) && ole_runtime_get.runned?
            end

            def runtime_stop
              ole_runtime_get.stop if respond_to? :ole_runtime_get
            end
            private :runtime_stop

            # Include and run {.runtime_new} runtime
            def runtime_run(host_port, platform_require)
              self.class.like_ole_runtime OleRuntime.runtime_new(self) unless\
                respond_to? :ole_runtime_get
              ole_runtime_get.run host_port, platform_require
            end
            private :runtime_run

            # Make new runtime module +AssOle::Runtimes::Claster::(Agent|Wp)+
            # for access to
            # +AssLauncher::Enterprise::Ole::(AgentConnection|WpConnection)+
            # @param inst [#runtime_type] +#runtime_type+ must returns
            #   +:wp+ or +:agent+ values
            # @return [Module]
            def self.runtime_new(inst)
              Module.new do
                is_ole_runtime inst.runtime_type
              end
            end

            def _connect(host_port, platform_require)
              runtime_run host_port, platform_require unless connected?
              begin
                authenticate unless authenticate?
              rescue
                runtime_stop
                raise
              end
              self
            end

            def authenticate
              fail 'Abstract method'
            end

            def authenticate?
              fail 'Abstract method'
            end
          end

          # Mixin for find infobase per name
          module InfoBaseFind
            def infobases
              fail 'Abstract method'
            end

            # Searching infobase in {#infobases} array
            # @param ib_name [String] infobase name
            # @return [WIN32OLE] +IInfoBaseShort+ ole object
            # @raise (see #infobases)
            def infobase_find(ib_name)
              infobases.find do |ib|
                ib.Name.upcase == ib_name.upcase
              end
            end

            # True if infobase registred in cluster
            # @param ib_name [String] infobase name
            # @raise (see #infobase_find)
            def infobase_include?(ib_name)
              !infobase_find(ib_name).nil?
            end
          end

          # Mixin for reconnect ole runtime
          module Reconnect
            def reconnect
              fail "Serevice #{host_port} not"\
                " available: #{tcp_ping.exception}" unless ping?
              return unless reconnect_required?
              ole_connector.__close__
              ole_connector.__open__ host_port
            end
            private :reconnect

            def reconnect_required?
              return true unless ole_connector.__opened__?
              begin
                _reconnect_required?
              rescue WIN32OLERuntimeError => e
                return true if e.message =~ %r{descr=10054}
              end
            end
            private :reconnect_required?

            def _reconnect_required?
              fail 'Abstract method'
            end
            private :_reconnect_required?
          end

          # @api private
          # Abstract server connection.
          # Mixin for {Cluster} and {ServerAgent}
          module ServerConnection
            # Server user name
            # See {#initialize} +user+ argument.
            # @return [String]
            attr_accessor :user

            # Server user password
            # See {#initialize} +password+ argument.
            # @return [String]
            attr_accessor :password

            # Host name
            attr_accessor :host

            # TCP port
            attr_accessor :port

            # @param host_port [String] string like a +host_name:port_number+
            # @param user [String] server user name
            # @param password [String] serever user password
            def initialize(host_port, user = nil, password = nil)
              fail ArgumentError, 'Host name require' if host_port.to_s.empty?
              @raw_host_port = host_port
              @host = parse_host
              @port = parse_port || default_port
              @user = user
              @password = password
            end

            # String like a +host_name:port_number+.
            # @return [String]
            def host_port
              "#{host}:#{port}"
            end

            def parse_port
              p = @raw_host_port.split(':')[1].to_s.strip
              return p unless p.empty?
            end
            private :parse_port

            def parse_host
              p = @raw_host_port.split(':')[0].to_s.strip
              fail ArgumentError, "Invalid host_name for `#{@raw_host_port}'" if\
                p.empty?
              p
            end
            private :parse_host

            def default_port
              fail 'Abstract method'
            end

            # Return +true+ if TCP port available on server
            def ping?
              tcp_ping.ping?
            end

            require 'net/ping/tcp'
            # @return [Net::Ping::TCP] instance
            def tcp_ping
              @tcp_ping ||= Net::Ping::TCP.new(host, port)
            end

            def eql?(other)
              host.upcase == other.host.upcase && port == other.port
            end
            alias_method :==, :eql?
          end
        end

        # @api private
        # Object descrbed 1C server agent connection.
        # @example
        #   # Get 1C:Eneterprise serever agent connection object and connect
        #   # to net service
        #   sagent = ServerAgent.new('localhost:1540', 'admin', 'password')
        #     .connect('~> 8.3.8.0')
        #
        #   # Working with serever agent connection
        #   sagent.ConnectionString #=> "tcp://localhost:1540"
        #   cl = sagent.cluster_find 'localhost', '1542'
        #
        #   # Close connection
        #   sagent.disconnect
        #
        module ServerAgent
          include Support::ServerConnection
          include Support::OleRuntime
          include Support::Reconnect

          # Make new object of anonymous class which included this module.
          def self.new(host_port, user, password)
            Class.new do
              include ServerAgent
            end.new host_port, user, password
          end

          # @return [String] wrapper for {InfoBase::DEFAULT_SAGENT_PORT}
          def default_port
            InfoBase::DEFAULT_SAGENT_PORT
          end

          def runtime_type
            :agent
          end

          # Connect to 1C:Eneterprise server via OLE
          # @note while connecting in instance class will be included
          # {.runtime_new} module
          # @param platform_require [String Gem::Requirement]
          # 1C:Eneterprise version required
          # @return +self+
          def connect(platform_require)
            _connect(host_port, platform_require)
          end

          # Authenticate {#user}
          # @raise if not connected
          def authenticate
            AuthenticateAgent(user.to_s, password.to_s) if\
              connected? && !authenticate?
          end

          # True if #{user} authenticate
          def authenticate?
            return false unless connected?
            begin
              ole_connector.GetAgentAdmins
            rescue WIN32OLERuntimeError
              return false
            end
            true
          end

          # @return [nil WIN32OLE] +IClusterInfo+ ole object
          # @raise if not connected
          def cluster_find(host, port)
            reconnect
            GetClusters().find do |cl|
              cl.HostName.upcase == host.upcase && cl.MainPort == port.to_i
            end
          end

          # TODO
          def platform_require
            return unless connected?
            ole_connector.send(:__ole_binary__).requirement.to_s
          end

          def _reconnect_required?
            getClusters.empty?
          end
          private :_reconnect_required?
        end

        require 'ass_maintainer/info_base/server_ib/enterprise_servers/wp_connection'

        # @api private
        # Object descrbed 1C cluster
        class Cluster
          # Deafult 1C:Enterprise cluster TCP port
          DEF_PORT = '1541'

          include Support::ServerConnection
          include Support::SendToOle
          include Support::InfoBaseFind

          # @return [String] {DEF_PORT}
          def default_port
            DEF_PORT
          end

          # Attache cluster into serever agent
          # @param agent [ServerAgent]
          # @raise (see #authenticate)
          def attach(agent)
            @sagent = agent unless @sagent
            ole_set
            authenticate
          end

          # @return [ServerAgent] which cluster attached
          # @raise [RuntimeError] unless cluster attached
          def sagent
            fail 'Cluster must be attachet to ServerAgent' unless @sagent
            @sagent
          end

          # @return +IClusterInfo+ ole object
          # @raise [RuntimeError] if cluster not found on {#sagent} server
          def ole
            fail ArgumentError, "Cluster `#{host_port}'"\
              " not found on server `#{sagent.host_port}'" unless @ole
            @ole
          end

          # True if cluster attached into {#sagent} serever
          def attached?
            !@sagent.nil? && !@ole.nil?
          end

          # Authenticate cluster user
          # @raise (see #ole)
          def authenticate
            sagent.Authenticate(ole, user.to_s, password.to_s)
            self
          end

          def ole_set
            @ole = sagent.cluster_find(host, port)
            ole
          end
          private :ole_set

          # @return [Array<WIN32OLE>] aray of +IInfoBaseShort+ ole objects
          # registred in cluster
          # @raise (see #ole)
          # @raise (see #sagent)
          def infobases
            sagent.GetInfoBases(ole)
          end

          # @return [nil Array<Wrappers::Session>] sessions for infobase
          # runned in cluster. +nil+ if infobase +ib_name+ not registred in
          # cluster.
          # @param ib_name [String] infobase name
          # @raise (see #sagent)
          def infobase_sessions(ib_name)
            ib = infobase_find(ib_name)
            return unless ib
            sagent.GetInfoBaseSessions(ole, ib).map do |s|
              Wrappers::Session.new(s, self)
            end
          end

          # All Working processes in cluster
          # @return [Array<Wrappers::WorkingProcessInfo]
          def wprocesses
            sagent.GetWorkingProcesses(ole).map do |wpi|
              Wrappers::WorkingProcessInfo.new(wpi, self)
            end
          end

          # Connect to working process
          # @return [WpConnection] object for comunication with 1C Working
          #   process
          def wp_connection(infobase_wrapper)
            if !@wp_connection.nil? && !@wp_connection.ping?
              @wp_connection = nil
            end
            @wp_connection ||= alive_wprocess_get.connect(infobase_wrapper)
          end

          def alive_wprocess_get
            wp_info = wprocesses.select{|p| p.Running == 1 && p.ping?}[0]
            fail 'No alive working processes found' unless wp_info
            wp_info
          end

          # Delete infobase
          # @param infobase_wrapper [InfoBaseWrapper] infobase wrapper
          # @param mode [Symbol] defines what should do with
          #   infobase's database. See {WpConnection::DROP_MODES}
          def drop_infobase!(infobase_wrapper, mode)
            wp_connection(infobase_wrapper).drop_infobase!(mode)
          end
        end

        # @api private
        # Wrappers for 1C OLE objects
        module Wrappers
          # @api private
          # Wrapper for 1C:Enterprise +IWorkingProcessInfo+ ole object
          class WorkingProcessInfo
            include Support::SendToOle
            attr_reader :ole, :cluster, :sagent, :connection
            def initialize(ole, cluster)
              @ole, @cluster, @sagent = ole, cluster, cluster.sagent
            end

            def connect(infobase_wrapper)
              WpConnection.new(self).connect(infobase_wrapper)
            end

            # Return +true+ if TCP port available on server
            def ping?
              tcp_ping.ping?
            end

            require 'net/ping/tcp'
            # @return [Net::Ping::TCP] instance
            def tcp_ping
              @tcp_ping ||= Net::Ping::TCP.new(hostName, mainPort)
            end
          end

          # @api private
          # Wrapper for 1C:Enterprise +ISessionInfo+ ole object
          class Session
            include Support::SendToOle

            # @api private
            # @return +ISessionInfo+ ole object
            attr_reader :ole

            # @api private
            # @return [EnterpriseServers::Cluster] cluster where session
            # registred
            attr_reader :cluster

            # @api private
            # @return [EnterpriseServers::ServerAgent] 1C server where session
            # registred
            attr_reader :sagent

            # @api private
            def initialize(ole, cluster)
              @ole, @cluster, @sagent = ole, cluster, cluster.sagent
            end

            # Terminate session
            def terminate
              sagent.TerminateSession(cluster.ole, ole)
            rescue WIN32OLERuntimeError
            end
          end
        end
      end
    end
  end
end
