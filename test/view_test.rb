require 'helper'
require 'lib/view_test_process'

class AdditionalLinkAttributesRenderer < WillPaginate::ViewHelpers::LinkRenderer
  def initialize(link_attributes = nil)
    super()
    @additional_link_attributes = link_attributes || { :default => 'true' }
  end

  def page_link(page, text, attributes = {})
    @template.link_to text, url_for(page), attributes.merge(@additional_link_attributes)
  end
end

class ViewTest < WillPaginate::ViewTestCase
  
  ## basic pagination ##

  def test_no_pagination_when_page_count_is_one
    paginate :per_page => 30
    assert_equal '', @html_result
  end

  def test_will_paginate_with_options
    paginate({ :page => 2 },
             :class => 'will_paginate', :prev_label => 'Prev', :next_label => 'Next') do
      assert_select 'a[href]', 4 do |elements|
        validate_page_numbers [1,1,3,3], elements
        # test rel attribute values:
        assert_select elements[1], 'a', '1' do |link|
          assert_equal 'prev start', link.first['rel']
        end
        assert_select elements.first, 'a', "Prev" do |link|
          assert_equal 'prev start', link.first['rel']
        end
        assert_select elements.last, 'a', "Next" do |link|
          assert_equal 'next', link.first['rel']
        end
      end
      assert_select 'span.current', '2'
    end
  end

  def test_will_paginate_using_renderer_class
    paginate({}, :renderer => AdditionalLinkAttributesRenderer) do
      assert_select 'a[default=true]', 3
    end
  end

  def test_will_paginate_using_renderer_instance
    renderer = WillPaginate::ViewHelpers::LinkRenderer.new
    renderer.gap_marker = '<span class="my-gap">~~</span>'
    
    paginate({ :per_page => 2 }, :inner_window => 0, :outer_window => 0, :renderer => renderer) do
      assert_select 'span.my-gap', '~~'
    end
    
    renderer = AdditionalLinkAttributesRenderer.new(:title => 'rendered')
    paginate({}, :renderer => renderer) do
      assert_select 'a[title=rendered]', 3
    end
  end

  def test_prev_next_links_have_classnames
    paginate do |pagination|
      assert_select 'span.disabled.prev_page:first-child'
      assert_select 'a.next_page[href]:last-child'
    end
  end

  def test_full_output
    paginate
    expected = <<-HTML
      <div class="pagination"><span class="disabled prev_page">&laquo; Previous</span>
      <span class="current">1</span>
      <a href="/foo/bar?page=2" rel="next">2</a>
      <a href="/foo/bar?page=3">3</a>
      <a href="/foo/bar?page=2" class="next_page" rel="next">Next &raquo;</a></div>
    HTML
    expected.strip!.gsub!(/\s{2,}/, ' ')
    
    assert_dom_equal expected, @html_result
  end

  ## advanced options for pagination ##

  def test_will_paginate_without_container
    paginate({}, :container => false)
    assert_select 'div.pagination', 0, 'main DIV present when it shouldn\'t'
    assert_select 'a[href]', 3
  end

  def test_will_paginate_without_page_links
    paginate({ :page => 2 }, :page_links => false) do
      assert_select 'a[href]', 2 do |elements|
        validate_page_numbers [1,3], elements
      end
    end
  end

  def test_container_id
    paginate do |div|
      assert_nil div.first['id']
    end
    
    # magic ID
    paginate({}, :id => true) do |div|
      assert_equal 'fixnums_pagination', div.first['id']
    end
    
    # explicit ID
    paginate({}, :id => 'custom_id') do |div|
      assert_equal 'custom_id', div.first['id']
    end
  end

  ## other helpers ##
  
  def test_paginated_section
    @template = <<-ERB
      <% paginated_section collection, options do %>
        <%= content_tag :div, '', :id => "developers" %>
      <% end %>
    ERB
    
    paginate
    assert_select 'div.pagination', 2
    assert_select 'div.pagination + div#developers', 1
  end
  
  ## parameter handling in page links ##
  
  def test_will_paginate_preserves_parameters_on_get
    @request.params :foo => { :bar => 'baz' }
    paginate
    assert_links_match /foo%5Bbar%5D=baz/
  end
  
  def test_will_paginate_doesnt_preserve_parameters_on_post
    @request.post
    @request.params :foo => 'bar'
    paginate
    assert_no_links_match /foo=bar/
  end
  
  def test_adding_additional_parameters
    paginate({}, :params => { :foo => 'bar' })
    assert_links_match /foo=bar/
  end
  
  def test_adding_anchor_parameter
    paginate({}, :params => { :anchor => 'anchor' })
    assert_links_match /#anchor$/
  end
  
  def test_removing_arbitrary_parameters
    @request.params :foo => 'bar'
    paginate({}, :params => { :foo => nil })
    assert_no_links_match /foo=bar/
  end
    
  def test_adding_additional_route_parameters
    paginate({}, :params => { :controller => 'baz', :action => 'list' })
    assert_links_match %r{\Wbaz/list\W}
  end
  
  def test_will_paginate_with_custom_page_param
    paginate({ :page => 2 }, :param_name => :developers_page) do
      assert_select 'a[href]', 4 do |elements|
        validate_page_numbers [1,1,3,3], elements, :developers_page
      end
    end    
  end
  
  def test_complex_custom_page_param
    @request.params :developers => { :page => 2 }
    
    paginate({ :page => 2 }, :param_name => 'developers[page]') do
      assert_select 'a[href]', 4 do |links|
        assert_links_match /\?developers%5Bpage%5D=\d+$/, links
        validate_page_numbers [1,1,3,3], links, 'developers[page]'
      end
    end
  end

  def test_custom_routing_page_param
    @request.symbolized_path_parameters.update :controller => 'dummy', :action => nil
    paginate :per_page => 2 do
      assert_select 'a[href]', 6 do |links|
        assert_links_match %r{/page/(\d+)$}, links, [2, 3, 4, 5, 6, 2]
      end
    end
  end

  def test_custom_routing_page_param_with_dot_separator
    @request.symbolized_path_parameters.update :controller => 'dummy', :action => 'dots'
    paginate :per_page => 2 do
      assert_select 'a[href]', 6 do |links|
        assert_links_match %r{/page\.(\d+)$}, links, [2, 3, 4, 5, 6, 2]
      end
    end
  end

  def test_custom_routing_with_first_page_hidden
    @request.symbolized_path_parameters.update :controller => 'ibocorp', :action => nil
    paginate :page => 2, :per_page => 2 do
      assert_select 'a[href]', 7 do |links|
        assert_links_match %r{/ibocorp(?:/(\d+))?$}, links, [nil, nil, 3, 4, 5, 6, 3]
      end
    end
  end

  ## internal hardcore stuff ##

  uses_mocha 'view internals' do
    def test_collection_name_can_be_guessed
      collection = mock
      collection.expects(:total_pages).returns(1)
      
      @template = '<%= will_paginate options %>'
      @controller.controller_name = 'developers'
      @view.assigns['developers'] = collection
      
      paginate(nil)
    end
  end
  
  def test_inferred_collection_name_raises_error_when_nil
    @template = '<%= will_paginate options %>'
    @controller.controller_name = 'developers'
    
    e = assert_raise ArgumentError do
      paginate(nil)
    end
    assert e.message.include?('@developers')
  end

  if ActionController::Base.respond_to? :rescue_responses
    # only on Rails 2
    def test_rescue_response_hook_presence
      assert_equal :not_found,
        ActionController::Base.rescue_responses['WillPaginate::InvalidPage']
    end
  end
  
end
