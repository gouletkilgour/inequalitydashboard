using JSON3
using Dates

# Minimum wage source data (PROVINCES, ABBR, RAW) is shared with
# data/minimum_wage_by_province.jl - see that include for source/methodology.
include(joinpath(@__DIR__, "_minimum_wage_raw.jl"))

# -- Hourly wage data ------------------------------------------------------
# Source: Statistics Canada, Table 14-10-0064-01, "Employee wages by
# industry, annual" (Labour Force Survey), downloaded via the StatCan Web
# Data Service API 2026-09-05:
#   https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1410006401
# Series selected: Total employees, all industries; Both full- and
# part-time employees; Total - Gender; 15 years and over. Years 1997-2025,
# the full range currently published for this table.

const WAGE_MEAN = Dict(
    "Newfoundland and Labrador" => Dict(
        "1997"=>13.16, "1998"=>13.06, "1999"=>13.08, "2000"=>13.77, "2001"=>14.33,
        "2002"=>14.88, "2003"=>15.48, "2004"=>15.45, "2005"=>16.15, "2006"=>17.04,
        "2007"=>17.99, "2008"=>19.09, "2009"=>20.02, "2010"=>21.17, "2011"=>22.11,
        "2012"=>23.6, "2013"=>24.6, "2014"=>25.56, "2015"=>24.84, "2016"=>24.91,
        "2017"=>25.37, "2018"=>26.2, "2019"=>26.5, "2020"=>27.61, "2021"=>28.45,
        "2022"=>29.4, "2023"=>31.01, "2024"=>32.48, "2025"=>33.42
    ),
    "Prince Edward Island" => Dict(
        "1997"=>11.8, "1998"=>11.96, "1999"=>12.3, "2000"=>12.63, "2001"=>13.2,
        "2002"=>13.61, "2003"=>14.51, "2004"=>15.1, "2005"=>15.17, "2006"=>15.84,
        "2007"=>16.27, "2008"=>17.43, "2009"=>18.15, "2010"=>19.04, "2011"=>19.4,
        "2012"=>20.28, "2013"=>20.49, "2014"=>20.9, "2015"=>21.36, "2016"=>21.73,
        "2017"=>22.33, "2018"=>22.48, "2019"=>22.87, "2020"=>24.27, "2021"=>25.3,
        "2022"=>26.84, "2023"=>27.94, "2024"=>29.56, "2025"=>30.11
    ),
    "Nova Scotia" => Dict(
        "1997"=>12.88, "1998"=>13.21, "1999"=>13.46, "2000"=>14.03, "2001"=>14.53,
        "2002"=>14.82, "2003"=>15.4, "2004"=>15.8, "2005"=>16.26, "2006"=>16.98,
        "2007"=>17.86, "2008"=>18.55, "2009"=>19.46, "2010"=>20.2, "2011"=>20.45,
        "2012"=>21.07, "2013"=>21.82, "2014"=>22.35, "2015"=>22.41, "2016"=>23.3,
        "2017"=>23.64, "2018"=>23.97, "2019"=>24.08, "2020"=>25.55, "2021"=>26.06,
        "2022"=>27.41, "2023"=>28.87, "2024"=>30.79, "2025"=>32.39
    ),
    "New Brunswick" => Dict(
        "1997"=>12.92, "1998"=>13.14, "1999"=>13.35, "2000"=>14.01, "2001"=>14.22,
        "2002"=>14.51, "2003"=>14.8, "2004"=>15.18, "2005"=>15.64, "2006"=>16.54,
        "2007"=>17.38, "2008"=>18.18, "2009"=>19.07, "2010"=>19.62, "2011"=>19.92,
        "2012"=>20.32, "2013"=>21.05, "2014"=>21.37, "2015"=>21.72, "2016"=>22.47,
        "2017"=>22.77, "2018"=>23.27, "2019"=>23.71, "2020"=>24.89, "2021"=>25.53,
        "2022"=>27.36, "2023"=>28.72, "2024"=>30.31, "2025"=>31.27
    ),
    "Quebec" => Dict(
        "1997"=>15.31, "1998"=>15.49, "1999"=>15.73, "2000"=>16.08, "2001"=>16.63,
        "2002"=>16.97, "2003"=>17.42, "2004"=>17.99, "2005"=>18.43, "2006"=>19.23,
        "2007"=>19.91, "2008"=>20.42, "2009"=>21.28, "2010"=>21.77, "2011"=>22.14,
        "2012"=>22.77, "2013"=>23.24, "2014"=>23.67, "2015"=>24.31, "2016"=>24.75,
        "2017"=>25.52, "2018"=>25.93, "2019"=>26.9, "2020"=>28.54, "2021"=>29.26,
        "2022"=>30.95, "2023"=>32.39, "2024"=>33.84, "2025"=>35.05
    ),
    "Ontario" => Dict(
        "1997"=>16.34, "1998"=>16.49, "1999"=>17.0, "2000"=>17.59, "2001"=>18.17,
        "2002"=>18.54, "2003"=>18.88, "2004"=>19.42, "2005"=>20.03, "2006"=>21.1,
        "2007"=>21.85, "2008"=>22.67, "2009"=>23.36, "2010"=>23.77, "2011"=>24.35,
        "2012"=>24.72, "2013"=>25.07, "2014"=>25.45, "2015"=>26.18, "2016"=>26.89,
        "2017"=>27.14, "2018"=>28.18, "2019"=>28.97, "2020"=>30.9, "2021"=>31.66,
        "2022"=>32.97, "2023"=>34.63, "2024"=>36.44, "2025"=>37.72
    ),
    "Manitoba" => Dict(
        "1997"=>13.83, "1998"=>14.05, "1999"=>14.49, "2000"=>14.98, "2001"=>15.34,
        "2002"=>15.74, "2003"=>16.08, "2004"=>16.79, "2005"=>17.2, "2006"=>17.9,
        "2007"=>18.81, "2008"=>19.66, "2009"=>20.46, "2010"=>21.04, "2011"=>21.58,
        "2012"=>22.0, "2013"=>22.34, "2014"=>22.95, "2015"=>23.68, "2016"=>24.17,
        "2017"=>24.77, "2018"=>25.07, "2019"=>25.65, "2020"=>26.8, "2021"=>27.2,
        "2022"=>28.09, "2023"=>29.38, "2024"=>30.39, "2025"=>31.63
    ),
    "Saskatchewan" => Dict(
        "1997"=>13.56, "1998"=>13.76, "1999"=>14.23, "2000"=>14.76, "2001"=>15.37,
        "2002"=>15.85, "2003"=>16.44, "2004"=>16.96, "2005"=>17.29, "2006"=>18.47,
        "2007"=>19.29, "2008"=>20.8, "2009"=>21.92, "2010"=>22.75, "2011"=>23.34,
        "2012"=>24.33, "2013"=>25.26, "2014"=>26.06, "2015"=>26.55, "2016"=>27.26,
        "2017"=>27.33, "2018"=>27.9, "2019"=>28.12, "2020"=>29.61, "2021"=>29.68,
        "2022"=>30.51, "2023"=>31.56, "2024"=>32.58, "2025"=>33.39
    ),
    "Alberta" => Dict(
        "1997"=>14.8, "1998"=>15.17, "1999"=>15.78, "2000"=>16.29, "2001"=>17.12,
        "2002"=>17.98, "2003"=>18.13, "2004"=>18.57, "2005"=>19.79, "2006"=>21.74,
        "2007"=>23.12, "2008"=>24.48, "2009"=>25.31, "2010"=>25.69, "2011"=>26.25,
        "2012"=>27.6, "2013"=>28.49, "2014"=>29.07, "2015"=>29.91, "2016"=>30.45,
        "2017"=>30.76, "2018"=>31.37, "2019"=>32.0, "2020"=>33.54, "2021"=>33.21,
        "2022"=>33.64, "2023"=>34.97, "2024"=>36.38, "2025"=>37.35
    ),
    "British Columbia" => Dict(
        "1997"=>16.91, "1998"=>17.16, "1999"=>17.32, "2000"=>17.63, "2001"=>17.98,
        "2002"=>18.6, "2003"=>19.03, "2004"=>19.01, "2005"=>19.36, "2006"=>20.31,
        "2007"=>21.14, "2008"=>22.15, "2009"=>22.93, "2010"=>23.32, "2011"=>23.72,
        "2012"=>24.15, "2013"=>24.81, "2014"=>24.97, "2015"=>25.84, "2016"=>26.03,
        "2017"=>26.53, "2018"=>27.41, "2019"=>28.14, "2020"=>30.15, "2021"=>31.3,
        "2022"=>32.63, "2023"=>34.76, "2024"=>36.65, "2025"=>37.95
    ),
    "Canada" => Dict(
        "1997"=>15.59, "1998"=>15.78, "1999"=>16.17, "2000"=>16.66, "2001"=>17.22,
        "2002"=>17.66, "2003"=>18.05, "2004"=>18.5, "2005"=>19.09, "2006"=>20.16,
        "2007"=>20.99, "2008"=>21.85, "2009"=>22.63, "2010"=>23.09, "2011"=>23.6,
        "2012"=>24.21, "2013"=>24.75, "2014"=>25.18, "2015"=>25.87, "2016"=>26.4,
        "2017"=>26.81, "2018"=>27.56, "2019"=>28.32, "2020"=>30.04, "2021"=>30.69,
        "2022"=>31.97, "2023"=>33.56, "2024"=>35.2, "2025"=>36.4
    )
)

const WAGE_MEDIAN = Dict(
    "Newfoundland and Labrador" => Dict(
        "1997"=>11.88, "1998"=>11.54, "1999"=>11.86, "2000"=>12.03, "2001"=>12.5,
        "2002"=>13.0, "2003"=>13.5, "2004"=>13.66, "2005"=>14.0, "2006"=>14.44,
        "2007"=>15.0, "2008"=>16.0, "2009"=>17.0, "2010"=>18.0, "2011"=>19.0,
        "2012"=>20.0, "2013"=>21.0, "2014"=>22.0, "2015"=>21.0, "2016"=>21.0,
        "2017"=>22.0, "2018"=>22.23, "2019"=>23.0, "2020"=>24.0, "2021"=>25.0,
        "2022"=>25.0, "2023"=>26.92, "2024"=>27.6, "2025"=>28.0
    ),
    "Prince Edward Island" => Dict(
        "1997"=>10.38, "1998"=>10.58, "1999"=>10.96, "2000"=>11.22, "2001"=>11.99,
        "2002"=>12.0, "2003"=>12.84, "2004"=>13.22, "2005"=>13.46, "2006"=>14.0,
        "2007"=>14.0, "2008"=>15.0, "2009"=>15.68, "2010"=>16.0, "2011"=>16.53,
        "2012"=>17.3, "2013"=>17.5, "2014"=>17.95, "2015"=>18.0, "2016"=>18.75,
        "2017"=>19.42, "2018"=>19.5, "2019"=>20.0, "2020"=>21.0, "2021"=>21.85,
        "2022"=>23.0, "2023"=>24.83, "2024"=>25.75, "2025"=>26.63
    ),
    "Nova Scotia" => Dict(
        "1997"=>11.24, "1998"=>11.54, "1999"=>12.0, "2000"=>12.25, "2001"=>12.69,
        "2002"=>12.93, "2003"=>13.46, "2004"=>13.94, "2005"=>14.0, "2006"=>14.59,
        "2007"=>15.38, "2008"=>15.75, "2009"=>16.5, "2010"=>17.0, "2011"=>17.44,
        "2012"=>17.8, "2013"=>18.18, "2014"=>19.0, "2015"=>19.0, "2016"=>19.89,
        "2017"=>20.0, "2018"=>20.0, "2019"=>20.17, "2020"=>21.83, "2021"=>22.12,
        "2022"=>23.08, "2023"=>24.62, "2024"=>25.64, "2025"=>27.37
    ),
    "New Brunswick" => Dict(
        "1997"=>11.54, "1998"=>12.0, "1999"=>12.0, "2000"=>12.39, "2001"=>12.5,
        "2002"=>12.98, "2003"=>13.0, "2004"=>13.5, "2005"=>13.75, "2006"=>14.23,
        "2007"=>15.0, "2008"=>15.7, "2009"=>16.41, "2010"=>17.0, "2011"=>17.0,
        "2012"=>17.54, "2013"=>18.0, "2014"=>18.0, "2015"=>18.72, "2016"=>19.1,
        "2017"=>19.5, "2018"=>20.0, "2019"=>20.0, "2020"=>21.0, "2021"=>22.33,
        "2022"=>23.4, "2023"=>25.0, "2024"=>25.7, "2025"=>27.0
    ),
    "Quebec" => Dict(
        "1997"=>13.75, "1998"=>14.0, "1999"=>14.0, "2000"=>14.42, "2001"=>15.0,
        "2002"=>15.0, "2003"=>15.38, "2004"=>16.0, "2005"=>16.3, "2006"=>16.8,
        "2007"=>17.29, "2008"=>17.78, "2009"=>18.56, "2010"=>19.0, "2011"=>19.11,
        "2012"=>20.0, "2013"=>20.0, "2014"=>20.19, "2015"=>20.88, "2016"=>21.37,
        "2017"=>22.0, "2018"=>22.0, "2019"=>23.08, "2020"=>25.0, "2021"=>25.0,
        "2022"=>27.0, "2023"=>28.0, "2024"=>29.5, "2025"=>30.0
    ),
    "Ontario" => Dict(
        "1997"=>14.9, "1998"=>15.0, "1999"=>15.0, "2000"=>15.8, "2001"=>16.16,
        "2002"=>16.48, "2003"=>16.84, "2004"=>17.1, "2005"=>17.95, "2006"=>18.21,
        "2007"=>19.0, "2008"=>19.45, "2009"=>20.0, "2010"=>20.0, "2011"=>20.57,
        "2012"=>21.0, "2013"=>21.0, "2014"=>21.63, "2015"=>22.0, "2016"=>22.6,
        "2017"=>22.95, "2018"=>23.63, "2019"=>24.35, "2020"=>26.0, "2021"=>26.7,
        "2022"=>27.88, "2023"=>29.0, "2024"=>30.0, "2025"=>31.25
    ),
    "Manitoba" => Dict(
        "1997"=>12.33, "1998"=>12.42, "1999"=>12.82, "2000"=>13.19, "2001"=>13.33,
        "2002"=>14.0, "2003"=>14.0, "2004"=>14.5, "2005"=>15.0, "2006"=>15.37,
        "2007"=>16.17, "2008"=>17.0, "2009"=>17.79, "2010"=>18.03, "2011"=>18.75,
        "2012"=>19.0, "2013"=>19.23, "2014"=>19.93, "2015"=>20.0, "2016"=>20.24,
        "2017"=>21.0, "2018"=>21.09, "2019"=>21.63, "2020"=>23.0, "2021"=>23.08,
        "2022"=>24.0, "2023"=>25.0, "2024"=>25.82, "2025"=>26.75
    ),
    "Saskatchewan" => Dict(
        "1997"=>12.0, "1998"=>12.31, "1999"=>12.69, "2000"=>13.0, "2001"=>13.85,
        "2002"=>14.0, "2003"=>14.74, "2004"=>15.0, "2005"=>15.38, "2006"=>16.32,
        "2007"=>17.1, "2008"=>18.4, "2009"=>19.0, "2010"=>20.0, "2011"=>20.19,
        "2012"=>21.0, "2013"=>22.0, "2014"=>22.62, "2015"=>23.0, "2016"=>24.0,
        "2017"=>24.04, "2018"=>24.67, "2019"=>24.5, "2020"=>26.0, "2021"=>26.0,
        "2022"=>26.59, "2023"=>27.1, "2024"=>28.5, "2025"=>28.85
    ),
    "Alberta" => Dict(
        "1997"=>13.0, "1998"=>13.46, "1999"=>14.0, "2000"=>14.42, "2001"=>15.0,
        "2002"=>15.45, "2003"=>15.87, "2004"=>16.0, "2005"=>17.25, "2006"=>18.75,
        "2007"=>20.0, "2008"=>21.0, "2009"=>22.0, "2010"=>22.12, "2011"=>22.66,
        "2012"=>24.0, "2013"=>24.77, "2014"=>25.0, "2015"=>25.82, "2016"=>26.0,
        "2017"=>26.44, "2018"=>26.92, "2019"=>27.2, "2020"=>29.0, "2021"=>28.85,
        "2022"=>28.85, "2023"=>30.0, "2024"=>30.77, "2025"=>32.0
    ),
    "British Columbia" => Dict(
        "1997"=>16.0, "1998"=>16.48, "1999"=>16.8, "2000"=>16.92, "2001"=>17.0,
        "2002"=>17.44, "2003"=>18.0, "2004"=>17.79, "2005"=>18.0, "2006"=>18.1,
        "2007"=>19.02, "2008"=>20.0, "2009"=>20.19, "2010"=>21.0, "2011"=>21.0,
        "2012"=>21.5, "2013"=>22.0, "2014"=>22.0, "2015"=>23.0, "2016"=>23.0,
        "2017"=>23.46, "2018"=>24.0, "2019"=>25.0, "2020"=>26.2, "2021"=>27.0,
        "2022"=>28.0, "2023"=>30.0, "2024"=>31.25, "2025"=>32.49
    ),
    "Canada" => Dict(
        "1997"=>14.0, "1998"=>14.29, "1999"=>14.5, "2000"=>15.0, "2001"=>15.38,
        "2002"=>15.67, "2003"=>16.0, "2004"=>16.35, "2005"=>17.0, "2006"=>17.5,
        "2007"=>18.0, "2008"=>19.0, "2009"=>19.75, "2010"=>20.0, "2011"=>20.0,
        "2012"=>20.6, "2013"=>21.0, "2014"=>21.63, "2015"=>22.0, "2016"=>22.5,
        "2017"=>23.0, "2018"=>23.32, "2019"=>24.04, "2020"=>25.64, "2021"=>26.0,
        "2022"=>27.0, "2023"=>28.79, "2024"=>30.0, "2025"=>30.77
    )
)

const YEARS = collect(1997:2025)

# -- Minimum wage: calendar-year time-weighted average ---------------------
# Converts each province's step-function minimum wage series (from RAW,
# shared with the Provincial Minimum Wages page) into one average-dollars-
# per-year figure, weighted by how many days each rate was actually in
# effect that year - most provinces change their minimum wage partway
# through the year, not on January 1, so a plain year-end or year-start
# snapshot would misrepresent the year's typical rate.

function step_value_at(dates::Vector{String}, rates::Vector{Float64}, d::Date)
    v = missing
    for (dt, r) in zip(dates, rates)
        if Date(dt) <= d
            v = r
        else
            break
        end
    end
    return v
end

function annual_avg_minwage(rows::Vector, year::Int)
    dates = [Date(r[1]) for r in rows]
    rates = Float64[r[2] for r in rows]
    date_strs = [r[1] for r in rows]
    year_start = Date(year, 1, 1)
    year_end = Date(year, 12, 31)
    breakpoints = sort(unique(vcat([year_start], filter(d -> year_start <= d <= year_end, dates))))
    total_days = 0
    weighted = 0.0
    for (i, bp) in enumerate(breakpoints)
        seg_end = i < length(breakpoints) ? breakpoints[i + 1] - Day(1) : year_end
        days = Dates.value(seg_end - bp) + 1
        weighted += step_value_at(date_strs, rates, bp) * days
        total_days += days
    end
    return weighted / total_days
end

minwage_annual = Dict{String, Dict{String, Float64}}()
for prov in PROVINCES
    minwage_annual[prov] = Dict(string(y) => round(annual_avg_minwage(RAW[prov], y), digits=4) for y in YEARS)
end
# Canada has no federal minimum wage for the general workforce, so its
# denominator is the unweighted mean of the ten provinces' time-weighted
# annual rates - the same convention the Average line on the Provincial
# Minimum Wages page uses.
minwage_annual["Canada"] = Dict(string(y) => round(sum(minwage_annual[p][string(y)] for p in PROVINCES) / length(PROVINCES), digits=4) for y in YEARS)

data = Dict{String, Any}()
for geo in vcat(PROVINCES, ["Canada"])
    data[geo] = Dict(
        "minwage" => minwage_annual[geo],
        "mean" => WAGE_MEAN[geo],
        "median" => WAGE_MEDIAN[geo],
    )
end

data_json = JSON3.write(data)
provinces_json = JSON3.write(PROVINCES)
years_json = JSON3.write(YEARS)

println("Data assembled. Building HTML...")

html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Wage to Minimum Wage Ratio &mdash; Inequality Dashboard</title>
  <link rel="stylesheet" href="../style.css" />
  <script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
    }

    main {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1.5rem;
    }

    section {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      min-height: 640px;
    }

    .about-section {
      grid-column: 1 / -1;
      min-height: 0;
      background: var(--bg);
    }

    #rankings { background: var(--bg); }

    .section-label {
      font-size: 0.7rem;
      font-weight: 600;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--muted);
      padding: 0.75rem 1.25rem;
      border-bottom: 1px solid var(--border);
      background: var(--bg);
      flex-shrink: 0;
    }

    #chart { flex: 1; min-height: 540px; }

    .chart-controls {
      padding: 0.6rem 1rem;
      border-bottom: 1px solid var(--border);
      background: var(--bg);
      flex-shrink: 0;
      display: flex;
      align-items: center;
      gap: 1rem;
      flex-wrap: wrap;
    }

    .ctrl-group { display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }

    .chart-ctrl-label { font-size: 0.75rem; font-weight: 500; color: var(--muted); }

    .chart-controls select {
      font-family: inherit;
      font-size: 0.82rem;
      padding: 0.22rem 0.5rem;
      border: 1px solid var(--border);
      border-radius: 4px;
      background: var(--bg);
      color: var(--text);
      cursor: pointer;
      outline: none;
    }

    .chart-controls select:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 2px rgba(42, 93, 176, 0.2);
    }

    .prose { flex: 1; padding: 1.5rem 1.75rem; line-height: 1.7; font-size: 0.93rem; overflow: auto; }
    .prose h2 { font-size: 1rem; font-weight: 600; margin-bottom: 0.75rem; color: var(--text); }
    .prose p { color: var(--text); margin-bottom: 1rem; }
    .prose ul { color: var(--text); margin: 0 0 1rem 1.25rem; }
    .prose li { margin-bottom: 0.35rem; }
    .prose p:last-child, .prose ul:last-child { margin-bottom: 0; }
    .prose strong { color: var(--text); font-weight: 600; }
    .prose a { color: var(--accent, #2a5db0); }
    .source { font-size: 0.75rem; color: var(--muted); margin-top: 1.25rem; }

    .rank-controls {
      padding: 0.75rem 1rem 0.65rem;
      border-bottom: 1px solid var(--border);
      background: var(--bg);
      flex-shrink: 0;
    }

    .rank-ctrl-label { font-size: 0.75rem; font-weight: 500; color: var(--muted); }

    .rank-slider-row {
      display: flex;
      align-items: center;
      gap: 0.6rem;
      margin-bottom: 0.4rem;
    }

    #rank-slider {
      flex: 1;
      accent-color: var(--accent, #2a5db0);
      cursor: pointer;
    }

    .rank-date-value {
      font-size: 0.78rem;
      font-weight: 600;
      color: var(--text);
      white-space: nowrap;
      min-width: 4em;
      text-align: right;
      font-variant-numeric: tabular-nums;
    }

    .rank-list { flex: 1; overflow-y: auto; padding: 0.4rem 0; }

    .rank-row {
      display: grid;
      grid-template-columns: 18px 1fr 60px;
      align-items: center;
      gap: 0.45rem;
      padding: 0.32rem 0.9rem;
      cursor: pointer;
      border-radius: 4px;
      margin: 1px 0.4rem;
      transition: background 0.1s;
    }

    .rank-row:hover        { background: var(--border); }
    .rank-row.rank-active  { background: var(--border); }
    .rank-row.rank-canada  { font-style: italic; }

    .rank-num  { font-size: 0.7rem; color: var(--muted); text-align: right; font-variant-numeric: tabular-nums; }
    .rank-name { font-size: 0.8rem; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .rank-val  { font-size: 0.76rem; color: var(--muted); font-variant-numeric: tabular-nums; text-align: right; }

    @media (max-width: 700px)  { main { grid-template-columns: 1fr; } }
  </style>
</head>
<body>

<div class="page" style="padding-bottom: 1rem;">
  <header class="site-header">
    <h1><a href="../index.html">Inequality Dashboard</a></h1>
    <p class="subtitle">Stone Centre on Wealth and Income Inequality | Vancouver School of Economics | University of British Columbia</p>
  </header>

  <p class="breadcrumb"><a href="../index.html">&larr; All categories</a> / <a href="../minimum_wage.html">Minimum Wage</a></p>

  <h2 class="post-title">Wage to Minimum Wage Ratio</h2>
</div>

<main class="page" style="padding: 1.5rem 1.5rem;">
  <section>
    <div class="section-label">Chart</div>
    <div class="chart-controls">
      <div class="ctrl-group">
        <span class="chart-ctrl-label">Statistic:</span>
        <select id="stat-select">
          <option value="mean">Mean</option>
          <option value="median" selected>Median</option>
        </select>
      </div>
    </div>
    <div id="chart"></div>
  </section>

  <section id="rankings">
    <div class="section-label">Provincial Rankings</div>
    <div class="rank-controls">
      <div class="rank-slider-row">
        <span class="rank-ctrl-label">Year</span>
        <input type="range" id="rank-slider" />
        <span id="rank-slider-date" class="rank-date-value"></span>
      </div>
    </div>
    <div id="rank-list" class="rank-list"></div>
  </section>

  <section class="about-section">
    <div class="section-label">About this data</div>
    <div class="prose">
      <h2>The Ratio</h2>
      <p>Each line is a province&rsquo;s <strong>hourly wage &divide; minimum wage</strong> ratio, by year. The numerator is Statistics Canada&rsquo;s Labour Force Survey estimate of the average (mean) or median hourly wage rate, for both full- and part-time employees combined, all industries, all ages 15 and over, both sexes. The denominator is that province&rsquo;s general (basic adult) minimum wage &mdash; the same series shown on the <a href="minimum_wage_by_province.html">Provincial Minimum Wages</a> page &mdash; averaged over the calendar year and weighted by how many days each rate was actually in effect, since most provinces raise their minimum wage partway through the year rather than on January 1.</p>
      <p><strong>Canada</strong>&rsquo;s wage figures are Statistics Canada&rsquo;s own national LFS estimate, not an average of the provinces. Since there is no federal minimum wage for the general workforce, Canada&rsquo;s minimum-wage denominator is the unweighted mean of the ten provinces&rsquo; time-weighted annual rates &mdash; the same convention used for the Average line on the Provincial Minimum Wages page.</p>

      <h2>Mean vs. Median</h2>
      <p>The <strong>mean</strong> hourly wage is pulled upward by high earners, so mean/minimum-wage ratios run higher and are more sensitive to changes at the top of the wage distribution. The <strong>median</strong> hourly wage &mdash; the wage of the middle-ranked worker &mdash; is less affected by high earners and is generally the more meaningful benchmark for how the minimum wage compares to a &ldquo;typical&rdquo; worker&rsquo;s pay.</p>
      <p>A falling ratio over time means the minimum wage has risen faster than typical wages (workers near the bottom catching up); a rising ratio means typical wages have outpaced minimum-wage increases.</p>

      <p class="source">Sources: Statistics Canada, Table <a href="https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1410006401" target="_blank" rel="noopener">14-10-0064-01</a>, Employee wages by industry, annual (Labour Force Survey), downloaded 2026-09-05. Minimum wage data: Employment and Social Development Canada, Minimum Wage Database (open.canada.ca, dataset 390ee890-59bb-4f34-a37c-9732781ef8a0) &mdash; see the Provincial Minimum Wages page for full methodology notes. Both series run 1997&ndash;2025, the range for which the wage table has data.</p>
    </div>
  </section>
</main>

<script>
  const DATA = $(data_json);
  const PROVINCES = $(provinces_json);
  const YEARS = $(years_json);
  const CANADA_NAME = "Canada";

  const HIGHLIGHT_COLOR = "#2a78d6";
  const CANADA_HIGHLIGHT_COLOR = "#e34948";
  const MUTED_COLOR = "#c3c2b7";
  const CANADA_COLOR = "#e34948";

  var currentProvince = CANADA_NAME;
  var currentStat = "median";

  function ratioSeries(geo, stat) {
    return YEARS.map(function(y) {
      var wage = DATA[geo][stat][String(y)];
      var minwage = DATA[geo].minwage[String(y)];
      return wage / minwage;
    });
  }

  var MARGIN_T = 50, MARGIN_B = 130;

  function statLabel() { return currentStat === "mean" ? "Mean" : "Median"; }

  function buildLayout() {
    var el    = document.getElementById("chart");
    var plotH = Math.max((el.offsetHeight || 480) - MARGIN_T - MARGIN_B, 80);
    var noteY = -((MARGIN_B - 15) / plotH);
    return {
      title: { text: statLabel() + " Hourly Wage to Minimum Wage Ratio" },
      xaxis: { title: { text: "Year" }, dtick: 5 },
      yaxis: { title: { text: "Ratio (Hourly Wage \u00f7 Minimum Wage)" } },
      showlegend: false,
      margin: { l: 60, b: MARGIN_B, r: 20, t: MARGIN_T },
      paper_bgcolor: "white",
      plot_bgcolor: "#E5ECF6",
      hovermode: "closest",
      annotations: [{
        xref: "paper", yref: "paper",
        x: 0.5, y: noteY,
        xanchor: "center", yanchor: "bottom",
        showarrow: false,
        text: "Chart created by the Stone Centre on Wealth and Income Inequality<br>at the Vancouver School of Economics (UBC) using wage data from Statistics Canada and minimum wage data from Employment and Social Development Canada",
        font: { size: 9, color: "#b0b0b0" },
      }],
    };
  }

  function buildTraces(selected) {
    var traces = PROVINCES.map(function(prov) {
      var isSel = prov === selected;
      var y = ratioSeries(prov, currentStat);
      var wages = YEARS.map(function(yr) { return DATA[prov][currentStat][String(yr)]; });
      var minwages = YEARS.map(function(yr) { return DATA[prov].minwage[String(yr)]; });
      return {
        type: "scatter",
        mode: "lines",
        name: prov,
        x: YEARS,
        y: y,
        line: { color: isSel ? HIGHLIGHT_COLOR : MUTED_COLOR, width: isSel ? 3 : 1.5 },
        opacity: isSel ? 1 : 0.55,
        customdata: YEARS.map(function(yr, i) { return [wages[i], minwages[i]]; }),
        hovertemplate: prov + "<br>%{x}<br>" + statLabel() + " wage: \$%{customdata[0]:.2f}/hr<br>Minimum wage: \$%{customdata[1]:.2f}/hr<br>Ratio: %{y:.2f}\u00d7<extra></extra>",
        hoverinfo: isSel ? undefined : "skip",
      };
    });

    var canadaSel = selected === CANADA_NAME;
    var canadaY = ratioSeries(CANADA_NAME, currentStat);
    var canadaWages = YEARS.map(function(yr) { return DATA[CANADA_NAME][currentStat][String(yr)]; });
    var canadaMinwages = YEARS.map(function(yr) { return DATA[CANADA_NAME].minwage[String(yr)]; });
    traces.push({
      type: "scatter",
      mode: "lines",
      name: CANADA_NAME,
      x: YEARS,
      y: canadaY,
      line: { color: canadaSel ? CANADA_HIGHLIGHT_COLOR : CANADA_COLOR, width: canadaSel ? 3 : 2, dash: canadaSel ? "solid" : "dot" },
      opacity: 1,
      customdata: YEARS.map(function(yr, i) { return [canadaWages[i], canadaMinwages[i]]; }),
      hovertemplate: CANADA_NAME + "<br>%{x}<br>" + statLabel() + " wage: \$%{customdata[0]:.2f}/hr<br>Minimum wage: \$%{customdata[1]:.2f}/hr<br>Ratio: %{y:.2f}\u00d7<extra></extra>",
    });

    return traces.sort(function(a, b) {
      return (a.name === selected ? 1 : 0) - (b.name === selected ? 1 : 0);
    });
  }

  var rankYearIndex = YEARS.length - 1;

  function renderRanking() {
    var year = YEARS[rankYearIndex];
    document.getElementById("rank-slider-date").textContent = String(year);

    var entries = PROVINCES.concat([CANADA_NAME]).map(function(name) {
      return { name: name, value: DATA[name][currentStat][String(year)] / DATA[name].minwage[String(year)] };
    }).sort(function(a, b) { return b.value - a.value; });

    document.getElementById("rank-list").innerHTML = entries.map(function(e, i) {
      var cls = "rank-row"
              + (e.name === currentProvince ? " rank-active" : "")
              + (e.name === CANADA_NAME ? " rank-canada" : "");
      return '<div class="' + cls + '" onclick="selectProvince(\'' + e.name + '\')">'
           + '<span class="rank-num">' + (i + 1) + '</span>'
           + '<span class="rank-name">' + e.name + '</span>'
           + '<span class="rank-val">' + e.value.toFixed(2) + '\u00d7</span>'
           + '</div>';
    }).join('');
  }

  function selectProvince(prov) {
    currentProvince = prov;
    Plotly.react("chart", buildTraces(prov), buildLayout(), { responsive: true });
    renderRanking();
  }

  var sliderEl = document.getElementById("rank-slider");
  sliderEl.min = 0;
  sliderEl.max = YEARS.length - 1;
  sliderEl.value = rankYearIndex;
  sliderEl.addEventListener("input", function() {
    rankYearIndex = parseInt(this.value, 10);
    renderRanking();
  });

  document.getElementById("stat-select").addEventListener("change", function() {
    currentStat = this.value;
    Plotly.react("chart", buildTraces(currentProvince), buildLayout(), { responsive: true });
    renderRanking();
  });

  Plotly.newPlot("chart", buildTraces(currentProvince), buildLayout(), { responsive: true });
  renderRanking();

  document.getElementById("chart").on("plotly_click", function(evt) {
    if (evt.points && evt.points.length) {
      selectProvince(evt.points[0].data.name);
    }
  });

  var resizeTimer;
  new ResizeObserver(function() {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function() {
      Plotly.relayout("chart", buildLayout());
    }, 50);
  }).observe(document.getElementById("chart"));
</script>

</body>
</html>
"""

output = joinpath(@__DIR__, "wage_to_minimum_wage_ratio.html")
write(output, html)
println("Saved -> $output")

if Sys.isapple()
    run(`open $output`)
elseif Sys.iswindows()
    run(`cmd /c start $output`)
else
    run(`xdg-open $output`)
end
