# Methods added to this helper will be available to all templates in the application.
require 'uri'

# TODO - look these over.  I'm not sure all of them are used, and those that are... perhaps not efficiently.

module ApplicationHelper

  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::SanitizeHelper

  # truncate a string to the maxlength passed and then add "..." if truncated
  def truncate(text, length = 30, truncate_string = "...")
    return if text.nil?
    l = length - truncate_string.chars.length
    text.chars.length > length ? text[/\A.{#{l}}\w*\;?/m][/.*[\w\;]/m] + truncate_string : text
  end  

  # TODO - Rails has built-in helpers for just this kind of stuff.
  def format_date_time(inTime,params={})
    format_string = params[:format] || "long"
    format_string = case format_string
    when "short"
      "%m/%d/%Y - %I:%M %p %Z"
    when "short_no_tz"
      "%m/%d/%Y - %I:%M %p"
    when "long"
      "%A, %B %d, %Y - %I:%M %p %Z"
    else
      nil
    end
    inTime.strftime(format_string) unless inTime==nil
  end

  # Return a formatted date
  # Default format: %m/%d/%Y
  def format_date(date, format = "%m/%d/%Y")
    date.respond_to?(:strftime) ? date.strftime(format) : date.to_s
  end

  # similar to h, but does not escape html code which is helpful for showing italisized names
  # TODO - stop using this.  Trust, instead, the built-in method (in views) called #sanitize
  def hh(input)
    result = input.dup.strip

    result.gsub!(/["]|&(?![\w]+;)/) do | match |
      case match
        when '&' then '&amp;'
        when '"' then '&quot;'
        else          ''
      end
    end
    result
  end

  #this only applies to text attributions for now
  #author, source, copyright, and data supplier should be shown
  def has_hidden_attributions?(data_object)
    return false if !data_object.text?
    data_object.attributions.each do |attribution|
      #TODO: so.... copyright and datasource don't exist in the db. which foces me to do string compares, seems like a kudge 
      if attribution.agent_role.to_s!='Author' && attribution.agent_role.to_s!='Source' && attribution.agent_role.to_s!='Copyright' && attribution.agent_role.to_s!='Supplier'
        return true
      end
    end
    false
  end
    
  def external_link_icon
    image_tag('external_link.png',{:alt => 'external link', :title => 'external link'})
  end


  def taxon_concept_comments_path(taxon_concept)
    return "/taxon_concepts/#{taxon_concept.id}/comments/"
  end
       
   # format numbers with commas for digit separators
   def format_number_with_commas(st)
     st.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
   end
   
   # COMMENTED_OUT by Preston because this does not appear to be getting used.
   #
   # determine if user's browser is IE
#   def isMSIE?
#     request.env['HTTP_USER_AGENT'].downcase.index('msie')!=nil
#   end
  
   # render something inside of a particular layout
   #
   # useful for sub-layouts or nested layouts for particular sections of the site.
   def inside_layout(layout, &block)
     @template.instance_variable_set("@content_for_layout", capture(&block))

     layout = layout.include?("/") ? layout : "layouts/#{layout}" if layout
     buffer = eval("_erbout", block.binding)
     buffer.concat(@template.render_file(layout, true))
   end  
       
  # take an input string, split it up by spaces and return a comma delimited list of the words
  def meta_keywords(input_string,strip_html=true)

    keyword_list=''
    input_string=strip_tags(input_string) if strip_html
    input_string.split(' ').each {|word| keyword_list+=word + ","}
    keyword_list.chop! if keyword_list.length>0
    return keyword_list
  
  end
   
  # Link to a single stylesheet by first looking for a language version (stylesheet-<language>.css) or defaulting
  # to the provided stylesheet if the language version is not found.
  def eol_lang_main_stylesheet(stylesheet, options = {})
    current_language = Gibberish.current_language.to_s
    language_stylesheet = "/languages/#{current_language}/#{stylesheet}.css"

    if File.exists?(File.join(RAILS_ROOT, "public", language_stylesheet))
      stylesheet = language_stylesheet
    end

    # Make sure stylesheets are cached by language if we're caching
    options.merge!(:cache => "all-#{current_language}") if options[:cache]
    stylesheet_link_tag(*[stylesheet, options])
  end

  # show a description of the data quality in the 'title' tag of the data quality icons
  def data_quality_description(data_quality)
    case data_quality.downcase
      when 'bronze' then 'This content has not been scientifically vetted for accuracy.'[]
      when 'silver' then 'This content has been vetted but is not from a known trusted source.'[]
      when 'gold'   then 'This content has been scientifically vetted and is from a known trusted source.'[]
      else               ''
    end
  end

  # Version of error_messages_for that displays translated error messages
  # View the <custom></custom> section to see the relevant pieces changed from original
  # TODO: Move to a plugin?
  def eol_lang_error_messages_for(*params)
    options = params.extract_options!.symbolize_keys
    object = options.delete(:object)
    objects = object ? [object].flatten : params.collect {|object_name| instance_variable_get("@#{object_name}") }.compact
    count = objects.inject(0) {|sum, obj| sum + obj.errors.count }
    unless count.zero?
      html = {}
      [:id, :class].each do |key|
        if options.include?(key)
          value = options[key]
          html[key] = value unless value.blank?
        else
          html[key] = 'errorExplanation'
        end
      end
      options[:header_message] = "Validation Error"[] unless options.include?(:header_message)
      options[:message] ||= "There were problems with the following fields:"[:validation_following_fields] unless options.include?(:message)
      
      # <custom>
      # Invert the default error messages so we can look them up easily for translation
      default_error_messages_inverted = ActiveRecord::Errors.default_error_messages.invert      
      
      # Translate error messages
      error_messages = objects.map do |obj| 
        obj.errors.map do |field, error| 
          # Try translating the field name
          field = ActiveRecord::Base.human_attribute_name(field)[]

          # Make two versions of the error message:
          #   Example: is too short (minimum 3 characters)
          #   1) is too short (minimum %d characters)
          #   Use this to map with default_error_messages_inverted
          #   2) is too short (minimum {n} characters)
          #   Use this for Gibberish to translate with variables
          error_attributes = error.scan(/\d+/)
          error_default = error.gsub(/\d+/,"%d")
          error_translate = error.gsub(/\d+/,"{n}") # 
          error_index = default_error_messages_inverted[error_default]

          error = error_translate["validation_#{error_index}".to_sym, *error_attributes]
          
          if error =~ /^\^/
            error_display = error[1..-1]
          else
            error_display =  "#{field == 'Base' ? '' : field} #{error}" 
          end
          
          content_tag(:li,error_display)
        end
      end
      
      # </custom>
      
      contents = ''
      contents << content_tag(options[:header_tag] || :h2, options[:header_message]) unless options[:header_message].blank?
      contents << content_tag(:p, options[:message]) unless options[:message].blank?
      contents << content_tag(:ul, error_messages)

      content_tag(:div, contents, html)
    else
      ''
    end
  end
  
  def back_or_home(back_url)
    if back_url.blank?
      root_url
    else
      URI.decode(back_url)
    end
  end

  #TODO: wow... this method should be cleaned up
  def medium_thumb_partial(taxon, image_id_name = '', new_window = false)
    return_html = ''
    unless taxon.nil? or taxon.smart_medium_thumb.nil? or taxon.name.nil? 
      name = sanitize(strip_tags(taxon.name(current_user.expertise)))
      return_html = %Q{<a}
      return_html+= %Q{ target=\"_blank\" } if new_window
      return_html+= %Q{ id="#{image_id_name}_href"}       unless image_id_name == ''           
      return_html+= %Q{ href="/pages/#{taxon.respond_to?(:taxon_concept_id) ? taxon.taxon_concept_id : taxon.id}"><img}
      return_html+= %Q{ id="#{image_id_name}"}            unless image_id_name == ''
      return_html+= %Q{ src="#{taxon.smart_medium_thumb}" alt="#{name}"}
      return_html+= %Q{ title="#{name}"/></a>}
    end
    if !taxon.nil? && taxon.smart_medium_thumb.nil? && !taxon.name.nil?
      name = sanitize(strip_tags(taxon.name(current_user.expertise)))
      return_html = %Q{<a}
      return_html+= %Q{ target=\"_blank\" } if new_window
      return_html+= %Q{ id="#{image_id_name}_href"}       unless image_id_name == ''
      return_html+= %Q{ href="/pages/#{taxon.respond_to?(:taxon_concept_id) ? taxon.taxon_concept_id : taxon.id}"><img}
      return_html+= %Q{ id="#{image_id_name}"}            unless image_id_name == ''
      return_html+= %Q{ src="/images/eol_logo_gray.gif" alt="#{name}"}
      return_html+= %Q{ title="#{name}"/></a>}
    end
    return return_html
  end
  
  def random_image_thumb_partial(random_image, image_id_name = '', new_window = false)
    return_html=""
    unless random_image.nil?
      name = sanitize(strip_tags(random_image['scientific_name']))
      return_html = %Q{<a}
      return_html+= %Q{ target=\"_blank\" } if new_window
      return_html+= %Q{ id="#{image_id_name}_href"}       unless image_id_name == ''
      return_html+= %Q{ href="/pages/#{random_image['taxon_concept_id']}"><img}
      return_html+= %Q{ id="#{image_id_name}"}            unless image_id_name == ''
      return_html+= %Q{ src="#{random_image['image_cache_path']}" alt="#{name}"}
      return_html+= %Q{ title="#{name}"/></a>}
    end
    return return_html
  end
  
  # def agent_logo(agent, size = "large", params={})
  #   src = (agent.logo_cache_url != 0) ? agent.logo_url(size) : agent.logo_file_name
  #   return src if src.empty?
  #   project_name = hh(sanitize(agent.project_name))
  #   capture_haml do
  #     haml_tag :img, {:width => params[:width], :height => params[:height], 
  #                     :src => src,  :border => 0, :alt => project_name, 
  #                     :title => project_name, :class => "agent_logo"}
  #   end
  # end
  
  # def collection_logo(collection, size = "large", params={})
  #   src = ''
  #   src = collection.logo_url(size) if !collection.logo_cache_url.nil? && collection.logo_cache_url!=0
  #   return src if src.empty?
  #   collection_title = hh(sanitize(collection.title))
  #   capture_haml do
  #     haml_tag :img, {:width => params[:width], :height => params[:height],
  #                     :src => src, :border => 0, :alt => collection_title, 
  #                     :title => collection_title, :class => "agent-logo"}
  #   end
  # end

  #change this methods to haml methods after conversion 

  def external_link_to(*args, &block)
    #return text if link is blank
    return args[0] if args[1]==nil || args[1].blank?

    html_options = args[2] || {}
    html_options[:class] ||= ''
    html_options[:class] += ' external_link'
    html_options[:class] += ' external_link_popup' if $USE_EXTERNAL_LINK_POPUPS

    if html_options[:show_link_icon].nil? || html_options.delete(:show_link_icon) == true
      args[0] += " #{external_link_icon}"
    end
    link_to(args[0],args[1],html_options, &block)
  end

  def linked_name(taxon, link_name_string = '', new_window = false)
    return_html=""
    unless taxon.nil?
      scientific_name = taxon.quick_scientific_name(:italicized)
      common_name = taxon.quick_common_name(current_user.language)
      return_html = %Q{<a }
      return_html+= %Q{ target="_blank" } if new_window
      # return_html+= %Q{ id="#{h(scientific_name)}" }  unless link_name_string.empty? very strange id and was broken so I commented it out
      return_html+= %Q{ href="/pages/#{taxon.respond_to?(:taxon_concept_id) ? taxon.taxon_concept_id : taxon.id}">#{sanitize(scientific_name)}</a><br />}
      return_html+= %Q{#{sanitize(common_name)}} unless common_name.empty?
    end
    return return_html
  end
  
  def random_image_linked_name(random_image, new_window = false)
    return_html=""
    unless random_image.nil?
      scientific_name = random_image['scientific_name']
      common_name = random_image['common_name']
      return_html = %Q{<a }
      return_html+= %Q{ target="_blank" } if new_window
      #return_html+= %Q{ id="#{h(scientific_name)}"} very strange id and it was broken so I commented it out
      return_html+= %Q{ href="/pages/#{random_image['taxon_concept_id']}">#{sanitize(scientific_name)}</a><br />}
      return_html+= %Q{#{sanitize(common_name.firstcap)}} unless common_name.nil?
    end
    return return_html
  end

  def allow_some_html(text)
    return text.allow_some_html
  end
  
  # render a version of the classification that allows you to choose a particular clade
  #
  # Usage:
  #   <%=  clade_selector  %>
  #   <%=  clade_selector 'name-of-input-field-that-will-be-created' %>
  #   <%=  clade_selector 'name-of-input-field-that-will-be-created', :some_options => 'go here' %>
  #   <%=  clade_selector :some_options => 'go here' %>
  #
  # Options:
  #   value:            a HierarchyEntry or HierarchyEntry ID (currently selected)
  #   id:               ID of the outer-most HTML element of the clade selector (default: 'clade-selector')
  #   visible:          true/false - whether or not to show the clade selector by default (default: false)
  #   toggle:           true/false - whether or not to show the links to toggle the visibility (default: true)
  #   hierarchy:        the actual Hierarchy to use
  #   name:             the name of the input field to use (default: whatever you pass as field-name, or 'selected-clade-id')
  #   debug:            true/false - shows the hidden input field as a text field, if true
  #   show_clear:       true/false - whether or not to show the '[clear]' option to clear the selection
  #   on_select:        javascript to call everytime a clade is selected (clade_id is available as 'clade_id')
  #   on_clear:         javascript to call when the clear 'button' is clicked
  #   on_expand:        javascript to call when a '+' expand link is clicked
  #   on_unselect_all:  javascript to call whenever all clades are unselected (happens on_select and on_clear)
  #
  def clade_selector field_name = 'selected-clade-id', options = {}
    if field_name.is_a?Hash
      options = field_name 
      field_name = 'selected-clade-id'
    end
    options = { 
      :value => nil,
      :id => 'clade-selector',
      :visible => false,
      :toggle => true,
      :hierarchy => Hierarchy.default,
      :name => field_name,
      :show_text => 'show clade browser',
      :hide_text => 'hide clade browser',
      :debug => false,
      :show_clear => true,
      :selectable_clade_level => 0
    }.merge(options || {})

    options[:is_debug] = options[:debug]
    options.delete :debug
    options.delete :value if options[:value].to_s.strip.length == 0 or options[:value].to_i == 0 # essentially, nil has been passed along
    options[:value] = (options[:value].is_a?HierarchyEntry) ? options[:value] : HierarchyEntry.find(options[:value]) if options[:value]
    options[:value] = (params.include?:clade_to_expand and params[:clade_to_expand].to_i > 0) ? HierarchyEntry.find(params[:clade_to_expand]) : options[:value]
    options[:hierarchy] = Hierarchy.last unless options[:hierarchy] or options[:value]
    options[:show_text], options[:hide_text] = options[:text], options[:text] if options[:text]

    render :partial => 'shared/clade_selector', :locals => options
  end

  # for creating a group of image buttons
  #
  # Usage:
  #   <% image_button_group 'some-buttons' do |group| %>
  #     <%= group.image_button 'button1', '/some/path' %>
  #     <%= group.image_button 'button2', '/some/path' %>
  #   <% end %>
  #
  # This renders the shared/_image_button_group partial (for the whole group)
  # and, for each image_button, it renders the shared/_image_button partial
  #
  def image_button_group name, &block
    group        = ImageButtonGroup.new name, self
    buttons_html = capture(group, &block)
    group_html   = capture(group) do
      render :partial => 'shared/image_button_group', :locals => { :group => group, :buttons_html => buttons_html }
    end
    concat group_html, block.binding
  end

  # class used for an image_button_group
  #
  # when you say <%= group.image_button %> you're calling #image_button 
  # on an instance of ImageButtonGroup
  #
  class ImageButtonGroup
    attr_accessor :name
    def initialize name, action_view
      @name = name
      @action_view = action_view
    end
    def image_button name, path
      # "image_button group #{@name}, #{name} => #{path}"
      @action_view.render :partial => 'shared/image_button', :locals => { :group => self, :name => name, :path => path }
    end
  end

  # returns a string that can be used as a CSS class, given an object
  def css_class value
    value.to_s.strip.downcase.gsub(' ','') # TODO update to strip out all non alphanumeric characters
  end

  def unpublished_icon(options={})
    style = options[:style] ? "style=\"#{options[:style]}\"" : ''
    "<img src=\"/images/icons/unpublished.png\" alt=\"Unpublished\" title=\"Unpublished\" #{style} />"
  end

  def published_icon(options={})
    style = options[:style] ? "style=\"#{options[:style]}\"" : ''
    description = options[:agent_name] ? "From #{options[:agent_name]}" : ''
    "<img src=\"/images/icons/published.png\" alt=\"#{description}\" title=\"#{description}\" #{style} />"
  end
  
end
