class GameWeather
  def update_neighbor_map
    @neighbors_maps = {}
    begin
      connections = MapFactoryHelper.getMapConnections
      connections.each do |group|
        next unless group.is_a?(Array)
        group.each do |conn|
          next unless conn.is_a?(Array) && conn.length >= 4
          a, b = conn[0], conn[3]
          next unless a.is_a?(Integer) && b.is_a?(Integer) && a != b
          @neighbors_maps[a] ||= []
          @neighbors_maps[b] ||= []
          @neighbors_maps[a] << b unless @neighbors_maps[a].include?(b)
          @neighbors_maps[b] << a unless @neighbors_maps[b].include?(a)
        end
      end
    rescue StandardError => e
      echoln "Weather connections unavailable: #{e.message}"
    end
  end
end
