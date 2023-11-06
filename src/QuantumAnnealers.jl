module QuantumAnnealers

using HTTP
using JSON
using URIs

const BASE_URL = "https://na-west-1.cloud.dwavesys.com/sapi/v2"

function init(token::String)
    global headers = Dict("X-Auth-Token" => "$token", "Content-Type" => "application/json")
end

function solvers_available(filters::String="")
    uri = URI(BASE_URL * "/solvers/remote/")
    # filter = Dict("filter"=> "none,+id,+status,+avg_load,+properties.num_qubits,+properties.category")
    filter = Dict("filter"=> filters)
    uri = URI(uri; query=filter)
    response = HTTP.request("GET", uri, headers )
    res = JSON.parse(String(response.body))
    for i in 1:length(res)
        println( "$(res[i]["id"])" * "\n\t Status: " * res[i]["status"] * "\t Avg Load: $(res[i]["avg_load"]) "  )
    end
    return res
end

function solve_qubo(solver::String, Q::Dict{Int, Dict{Int, Float64}}, params::Dict{String, Any}=Dict())
    url = URI(BASE_URL * "/solvers/remote/")
    body = Dict("type" => "ising", "linear" => Dict(), "quadratic" => Q, "params" => params)
    response = HTTP.post(url, headers, JSON.json(body))
    job_id = JSON.parse(String(response.body))["id"]
    return fetch_results(job_id)
end

# function ising_sample(solver::String, h::Dict{Int,Float64}, J::Dict{Tuple{Int,Int},Float64}, num_reads::Int=100)
function ising_sample(solver::String, h, J, num_reads::Int=100)
    url = URI(BASE_URL * "/solvers/remote/")
    body = JSON.json(Dict("type" => "ising", "linear" => h, "quadratic" => J, "num_reads" => num_reads))
    response = HTTP.post(url, body=body)
    return JSON.parse(String(response.body))["id"]
end

function fetch_results(job_id::String)
    url = "$(BASE_URL)/jobs/$(job_id)/"
    response = HTTP.get(url, headers)
    return JSON.parse(String(response.body))
end

end
