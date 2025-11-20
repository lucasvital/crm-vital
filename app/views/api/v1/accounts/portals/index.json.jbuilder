json.payload do
  json.local_portals do
    json.array! @local_portals.each do |portal|
      json.partial! 'portal', formats: [:json], portal: portal, articles: []
    end
  end

  json.global_portals do
    json.array! @global_portals.each do |portal|
      json.partial! 'portal', formats: [:json], portal: portal, articles: []
    end
  end
end

json.meta do
  json.current_page @current_page
  json.local_portals_count @local_portals.size
  json.global_portals_count @global_portals.size
  json.total_portals_count @local_portals.size + @global_portals.size
end
