module SimpleGeo

  class Client

    @@connection = nil
    @@debug = false

    class << self

      def set_credentials(token, secret)
        @@connection = Connection.new(token, secret)
        @@connection.debug = @@debug
      end

      def debug=(debug_flag)
        @@debug = debug_flag
        @@connection.debug = @@debug  if @@connection
      end

      def debug
        @@debug
      end

      def add_record(record)
        raise SimpleGeoError, "Record has no layer"  if record.layer.nil?
        put Endpoint.record(record.layer, record.id), record
      end

      def delete_record(layer, id)
        delete Endpoint.record(layer, id)
      end

      def get_record(layer, id)
        record_hash = get Endpoint.record(layer, id)
        record = Record.parse_geojson_hash(record_hash)
        record.layer = layer
        record
      end

      def add_records(layer, records)
        features = {
          :type => 'FeatureCollection',
          :features => records.collect { |record| record.to_hash }
        }
        post Endpoint.add_records(layer), features
      end

      # This request currently generates a 500 error if an unknown id is passed in.
      def get_records(layer, ids)
        features_hash = get Endpoint.records(layer, ids)
        records = []
        features_hash['features'].each do |feature_hash|
          record = Record.parse_geojson_hash(feature_hash)
          record.layer = layer
          records << record
        end
        records
      end

      def get_history(layer, id)
        history_geojson = get Endpoint.history(layer, id)
        history = []
        history_geojson['geometries'].each do |point|
          history << {
            :created => Time.at(point['created']),
            :lat => point['coordinates'][1],
            :lon => point['coordinates'][0]
          }
        end
        history
      end

      def get_nearby_records(layer, options)
        if options[:geohash]
          endpoint = Endpoint.nearby_geohash(layer, options.delete(:geohash))
        elsif options[:ip]
          endpoint = Endpoint.nearby_ip_address(layer, options.delete(:ip))
        elsif options[:lat] && options[:lon]
          endpoint = Endpoint.nearby_coordinates(layer,
            options.delete(:lat), options.delete(:lon))
        else
          raise SimpleGeoError, "Either geohash or lat and lon is required"
        end

        options = nil  if options.empty?
        features_hash = get(endpoint, options)
        nearby_records = {
          :next_cursor => features_hash['next_cursor'],
          :records => []
        }
        features_hash['features'].each do |feature_hash|
          record = Record.parse_geojson_hash(feature_hash)
          record.layer = layer
          record_info = {
            :distance => feature_hash['distance'],
            :record => record
          }
          nearby_records[:records] << record_info
        end
        nearby_records
      end

      def get_nearby_address(lat, lon)
        geojson_hash = get Endpoint.nearby_address(lat, lon)
        HashUtils.symbolize_keys geojson_hash['properties']
      end

      def get_layer_information(layer)
        layer_info = get Endpoint.layer(layer)
        layer_info.delete('selfLink')
        HashUtils.symbolize_keys(layer_info)
      end

      def get_density(lat, lon, day, hour=nil)
        geojson_hash = get Endpoint.density(lat, lon, day, hour)
        geojson_hash = HashUtils.recursively_symbolize_keys(geojson_hash)
        if hour.nil?
          density_info = []
          geojson_hash[:features].each do |hour_geojson_hash|
            density_info << hour_geojson_hash[:properties].merge(
              {:geometry => hour_geojson_hash[:geometry]})
          end
          density_info
        else
          geojson_hash[:properties].merge({:geometry => geojson_hash[:geometry]})
        end
      end

      def get_overlaps(south, west, north, east, options=nil)
        info = get Endpoint.overlaps(south, west, north, east), options
        HashUtils.recursively_symbolize_keys(info)
      end

      # this API call seems to always return a 404
      def get_boundary(id)
        info = get Endpoint.boundary(id)
        HashUtils.recursively_symbolize_keys(info)
      end

      def get_contains(lat, lon)
        info = get Endpoint.contains(lat, lon)
        HashUtils.recursively_symbolize_keys(info)
      end

      def get_contains_ip_address(ip)
        info = get Endpoint.contains_ip_address(ip)
        HashUtils.recursively_symbolize_keys(info)
      end

      def get_locate(ip)
        info = get Endpoint.locate(ip)
        HashUtils.recursively_symbolize_keys(info)
      end

      def get(endpoint, data=nil)
        raise NoConnectionEstablished  if @@connection.nil?
        @@connection.get endpoint, data
      end

      def delete(endpoint, data=nil)
        raise NoConnectionEstablished  if @@connection.nil?
        @@connection.delete endpoint, data
      end

      def post(endpoint, data=nil)
        raise NoConnectionEstablished  if @@connection.nil?
        @@connection.post endpoint, data
      end

      def put(endpoint, data=nil)
        raise NoConnectionEstablished  if @@connection.nil?
        @@connection.put endpoint, data
      end
    end

  end

end
