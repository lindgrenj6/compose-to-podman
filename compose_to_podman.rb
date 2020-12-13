require 'yaml'
require 'fileutils'

def parse_compose_file
  # Read in the compose.yml file, either specified via cli arg or just using the default
  compose_file = YAML.load_file('./docker-compose.yml')
  # Symbolize the keys just to make life a bit easier
  compose_file = symbolize_keys(compose_file)
  @cli_strings = {}

  @cli_strings["_network"] = "docker network create #{File.basename(Dir.getwd)}" if compose_file[:services].count > 1

  # Go through each of the services, creating a "podman run" command
  compose_file[:services].each_key do |service_name|
    @cli_strings[service_name] = []
    service = compose_file[:services][service_name.to_sym]

    # service name:
    @cli_strings[service_name] << if service[:container_name]
                                    "--name #{service[:container_name]}"
                                  else
                                    "--name #{service_to_container_name(service_name)}"
                                  end
    # environment:
    @cli_strings[service_name] << service[:environment].map { |var| "-e \"#{var.kind_of?(Array) ? var.join('=') : var}\"" } unless service[:environment].nil?
    # volumes:
    unless service[:volumes].nil?
      @cli_strings[service_name] << service[:volumes].map { |vol| "-v \"#{vol}\"" }.join(' ')
    end

    # ports:
    @cli_strings[service_name] << service[:ports].map { |port| "-p \"#{port}\"" }.join(' ') unless service[:ports].nil?
    # network (if we have multiple svcs)
    @cli_strings[service_name] << "--network #{File.basename(Dir.getwd)}" if @cli_strings["_network"]
    # privileged
    @cli_strings[service_name] << '--privileged' if service[:privileged]
    # image:
    @cli_strings[service_name] << service[:image]
  end

  @cli_strings.transform_values! { |cmd| cmd.include?("network create") ? cmd : "podman run -d #{cmd.join(' ')}" }
end

# Get the name for the container in the form "dir_containername"
def service_to_container_name(service_name)
  [File.basename(Dir.getwd), service_name].join('_')
end

# If I had rails I wouldn't have had to copy/paste this BS. But so be it.
def symbolize_keys(hash)
  Hash[hash.map { |k, v| v.is_a?(Hash) ? [k.to_sym, symbolize_keys(v)] : [k.to_sym, v] }]
end

parse_compose_file.each do |svc, cmd|
  puts "# Service #{svc}:"
  puts cmd
  puts
end
