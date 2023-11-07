module QuantumAnnealers

using HTTP
using JSON
using URIs
using Base64

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

function get_solver(chip_id="Advantage_system6.3")
    response = HTTP.request("GET", BASE_URL * "/solvers/remote/$chip_id", headers )
    res = JSON.parse(String(response.body))
    @info "Getting solver $(res["id"]): $(res["status"])"
    res["properties"]["id"] = res["id"]
    return res["properties"]
end

function parse_b_and_j(biases, dwave_model)
    qubits = dwave_model["qubits"]
    couplers = dwave_model["couplers"]
    xy = couplers[1]
    lin_vec = fill(NaN, length(qubits))
    lin_vec[findfirst(==(xy[1]), qubits)] = biases["x"]
    lin_vec[findfirst(==(xy[2]), qubits)] = biases["y"]
    # Encoding the vector to base64
    lin_vec_bytes = reinterpret(UInt8, Float64[lin_vec...])
    lin = base64encode(lin_vec_bytes)

    # Similar process for quad_vec
    # quad_vec = fill(0.0, length(couplers))
    # quad_vec[1] = biases["xy"]
    quad_vec = [biases["xy"]]
    quad_vec_bytes = reinterpret(UInt8, Float64[quad_vec...])
    quad = base64encode(quad_vec_bytes)

    return lin, quad
end

function create_conditions(lin, quad, dwave_model; label="Test 1", num_reads=20)
    conditions = Dict("solver" => dwave_model["id"], 
                "label" => "QPU REST submission 1", 
                "data" => Dict("format" => "qp", "lin" => lin, "quad" => quad),
                "type" => "ising",
                "params" => Dict("num_reads" => num_reads)
                )
    return conditions
end

function post_problem(conditions)
    response = HTTP.request("POST", BASE_URL * "/problems", headers,
        body = JSON.json(conditions) )
    res = JSON.parse(String(response.body))
    return res
end

function get_answer(response)
    try
        response = HTTP.request("GET", BASE_URL * "/problems/$(response["id"])/answer", headers )
        res = JSON.parse(String(response.body))
        return res["answer"]
    catch
        @info response["status"]
        return 0
    end
end

function decode_energy(energies_encoded)
    # Decode the base64-encoded energies
    energies_bytes = base64decode(energies_encoded)

    # Convert the byte array into an array of floats (doubles)
    energies = reinterpret(Float64, energies_bytes)
end

function bytes_to_ising_solutions(solutions)
    # Initialize an array to store the Ising problem solutions
    bytes = base64decode(solutions)
    ising_solutions = Int[]

    # Iterate through each byte
    for byte in reverse(bytes)
        # Iterate through each bit in the byte in little-endian order
        for bit_index in 0:7
            # Extract the bit
            bit = (byte >> bit_index) & 0x01
            # Convert 0 to -1 for Ising representation
            ising_value = (bit == 0) ? -1 : 1
            push!(ising_solutions, ising_value)
        end
    end

    return ising_solutions
end

function decode_variables(active_variables)
    reinterpret(Int32, base64decode(active_variables))
end

function get_spins(answer)
    s1 = size(decode_energy(answer["energies"]),1)
    s2 = size(decode_variables(answer["active_variables"]),1)
    spins = reshape(bytes_to_ising_solutions(answer["solutions"]),:,s1)[end-s2+1:end,:]
    return spins
end

end
