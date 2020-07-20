describe "v1.2 - root", :type => [:request, :v1x2] do
  it "#openapi.json" do
    get("#{api_version}/openapi.json")

    expect(response.content_type).to eq("application/json")
    expect(response).to have_http_status(:ok)
  end
end
