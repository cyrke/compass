module Compass
  module Configuration
    # The adapters module provides methods that make configuration data from a compass project
    # adapt to various consumers of configuration data
    module Adapters
      def to_compiler_arguments(additional_options = {})
        engine_opts = to_sass_engine_options.merge(additional_options)
        # we have to pass the quiet option in the nested :sass hash to disambiguate it from the compass compiler's own quiet option.
        if engine_opts.has_key?(:quiet)
          engine_opts[:sass] ||= {}
          engine_opts[:sass][:quiet] = engine_opts.delete(:quiet)
        end
        [project_path, sass_path, css_path, engine_opts]
      end

      def to_sass_plugin_options
        locations = []
        locations << [sass_path, css_path] if sass_path && css_path
        Compass::Frameworks::ALL.each do |framework|
          locations << [framework.stylesheets_directory, File.join(css_path || css_dir || ".", framework.name)]
        end
        load_paths = []
        resolve_additional_import_paths.each do |additional_path|
          if additional_path.is_a?(String)
            locations << [additional_path, File.join(css_path || css_dir || ".", File.basename(additional_path))]
          else
            load_paths << additional_path
          end
        end
        plugin_opts = {:template_location => locations}
        plugin_opts[:style] = output_style if output_style
        plugin_opts[:line_comments] = line_comments
        if sass_3_4?
          plugin_opts[:sourcemap] = sourcemap ? :auto : :none
        else
          plugin_opts[:sourcemap] = sourcemap
        end
        plugin_opts[:cache] = cache unless cache.nil?
        plugin_opts[:cache_location] = cache_path unless cache_path.nil?
        plugin_opts[:quiet] = disable_warnings if disable_warnings
        plugin_opts[:compass] = {}
        plugin_opts[:compass][:environment] = environment
        plugin_opts.merge!(sass_options || {})
        plugin_opts[:load_paths] ||= []
        plugin_opts[:load_paths] += load_paths
        plugin_opts[:load_paths] << Compass::SpriteImporter.new
        plugin_opts[:full_exception] = (environment == :development)
        plugin_opts
      end

      def resolve_additional_import_paths
        (additional_import_paths || []).map do |path|
          if path.is_a?(String) && project_path && !absolute_path?(path)
            File.join(project_path, path)
          else
            path
          end
        end
      end

      def absolute_path?(path)
        # Pretty basic implementation
        path.index(File::SEPARATOR) == 0 || path.index(':') == 1
      end

      def to_sass_engine_options
        engine_opts = {:load_paths => sass_load_paths}
        engine_opts[:style] = output_style if output_style
        engine_opts[:line_comments] = line_comments
        if sass_3_4?
          engine_opts[:sourcemap] = sourcemap ? :auto : :none
        else
          engine_opts[:sourcemap] = sourcemap
        end
        engine_opts[:cache] = cache
        engine_opts[:cache_location] = cache_path
        engine_opts[:quiet] = disable_warnings if disable_warnings
        engine_opts[:compass] = {}
        engine_opts[:compass][:environment] = environment
        engine_opts[:full_exception] = (environment == :development)
        engine_opts.merge!(sass_options || {})
      end

      def sass_load_paths
        load_paths = []
        load_paths << sass_path if sass_path
        Compass::Frameworks::ALL.each do |f|
          load_paths << f.stylesheets_directory if File.directory?(f.stylesheets_directory)
        end
        importer = sass_options[:filesystem_importer] if sass_options && sass_options[:filesystem_importer]
        importer ||= Sass::Importers::Filesystem
        load_paths += resolve_additional_import_paths
        load_paths.map! do |p|
          next p if p.respond_to?(:find_relative)
          importer.new(p.to_s)
        end
        load_paths << Compass::SpriteImporter.new
        load_paths
      end

      def sass_3_4?
        Sass.version[:major] == 3 && Sass.version[:minor] == 4
      end
    end
    class Data
      include Adapters
    end
  end
end
