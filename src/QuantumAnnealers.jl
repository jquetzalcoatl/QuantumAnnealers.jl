module QuantumAnnealers

using HTTP
using JSON

const BASE_URL = "https://cloud.dwavesys.com/sapi"

function init(token::String)
    global headers = Dict("Authorization" => "Bearer $token", "Content-Type" => "application/json")
end

function solve_qubo(solver::String, Q::Dict{Int, Dict{Int, Float64}}, params::Dict{String, Any}=Dict())
    url = "$BASE_URL/solvers/$solver/jobs/"
    body = Dict("type" => "ising", "linear" => Dict(), "quadratic" => Q, "params" => params)
    response = HTTP.post(url, headers, JSON.json(body))
    job_id = JSON.parse(String(response.body))["id"]
    return fetch_results(solver, job_id)
end

# function fetch_results(solver::String, job_id::String)
#     url = "$BASE_URL/solvers/$solver/jobs/$job_id/"
#     response = HTTP.get(url, headers)
#     result = JSON.parse(String(response.body))
#     return result
# end

# function ising_sample(solver::String, h::Dict{Int,Float64}, J::Dict{Tuple{Int,Int},Float64}, num_reads::Int=100)
function ising_sample(solver::String, h, J, num_reads::Int=100)
    url = "$(BASE_URL)/solvers/$(solver)/jobs/"
    body = JSON.json(Dict("type" => "ising", "linear" => h, "quadratic" => J, "num_reads" => num_reads))
    response = HTTP.post(url, body=body)
    return JSON.parse(String(response.body))["id"]
end

function fetch_results(job_id::String)
    url = "$(BASE_URL)/jobs/$(job_id)/"
    response = HTTP.get(url, headers=HEADERS)
    return JSON.parse(String(response.body))
end

end
