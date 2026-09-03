using Pkg
Pkg.add(["HTTP", "JSON3", "Dates"])

using HTTP, JSON3, Dates

# -- StatsCan WDS API ---------------------------------------------------------
# Table  : 11-10-0239-01  "Income of individuals by age group, gender and
#          income source, Canada, provinces and selected census metropolitan
#          areas"  https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1110023901
# Source : Canadian Income Survey / T1 Family File, Statistics Canada.
#          Annual, 1976-2024.
# Series : Canada only (no provincial breakdown), age group "15 years and
#          over", for Men+ and Women+ separately, for two income concepts
#          (Total income, Market income), for two statistics (Average
#          income excluding zeros = "mean", Median income excluding zeros =
#          "median") - 8 series in total, each 1976-2024 annual.
#
#          IMPORTANT: this table reports income in 2024 CONSTANT dollars
#          (inflation-adjusted), not current/nominal dollars - confirmed via
#          the WDS getCodeSets endpoint (memberUomCode 455 = "2024 constant
#          dollars"), not stated on the table's own landing page.
#
#          Two further derived series (the gender gap in mean/median income,
#          in both percentage and dollar terms) are computed client-side in
#          the page's JavaScript from the four base series for whichever
#          income concept is selected, rather than being separately fetched.
# Docs   : https://www.statcan.gc.ca/en/developers/wds/user-guide
#
# This script writes gender_income_gap.html into the same directory it lives
# in (website/data/), already styled to match the rest of the Inequality
# Dashboard site. Re-running it regenerates a ready-to-publish page - no
# manual reskin step.
# -----------------------------------------------------------------------------

const GENDERS = ["men", "women"]
const MEASURES = ["total", "market"]
const STATS = ["mean", "median"]

# vector_ids[measure][gender][stat] => Int, resolved via
# getSeriesInfoFromCubePidCoord against coordinates of the form
# "1.1.<gender>.<measure>.<stat>.0.0.0.0.0" (Geography=Canada=1,
# Age group=15 years and over=1; gender 2=Men+/3=Women+; income source
# 1=Total income/2=Market income; statistics 4=Average(excl. zeros)/
# 5=Median(excl. zeros)).
const VECTOR_IDS = Dict(
    "total" => Dict(
        "men"   => Dict("mean" => 107660932, "median" => 107660933),
        "women" => Dict("mean" => 107661007, "median" => 107661008),
    ),
    "market" => Dict(
        "men"   => Dict("mean" => 107660937, "median" => 107660938),
        "women" => Dict("mean" => 107661012, "median" => 107661013),
    ),
)

const N_PERIODS = 60   # 1976-2024 annual; fetch up to 60 periods
const ENDPOINT  = "https://www150.statcan.gc.ca/t1/wds/rest/getDataFromVectorsAndLatestNPeriods"

function fetch_series(vector_ids::Vector{Int}, n::Int)
    body    = JSON3.write([Dict("vectorId" => v, "latestN" => n) for v in vector_ids])
    headers = ["Content-Type" => "application/json"]
    resp    = HTTP.post(ENDPOINT, headers, body)
    parsed  = JSON3.read(String(resp.body))

    results = Dict{Int, NamedTuple{(:years, :values), Tuple{Vector{Int}, Vector{Float64}}}}()
    for item in parsed
        item[:status] == "SUCCESS" || error("API error: $(item[:status])")
        pts    = item[:object][:vectorDataPoint]
        vid    = item[:object][:vectorId]
        years  = [year(Date(string(p[:refPer]))) for p in pts]
        values = Float64[p[:value] for p in pts]
        results[vid] = (years = years, values = values)
    end
    return results
end

println("Fetching individual income by gender from Statistics Canada...")

all_vector_ids = Int[VECTOR_IDS[m][g][s] for m in MEASURES for g in GENDERS for s in STATS]
raw = fetch_series(all_vector_ids, N_PERIODS)

# Build nested Dict: measure -> gender -> stat -> {years, values}
data = Dict{String, Any}()
for measure in MEASURES
    data[measure] = Dict{String, Any}()
    for gender in GENDERS
        data[measure][gender] = Dict{String, Any}()
        for stat in STATS
            vid = VECTOR_IDS[measure][gender][stat]
            d   = raw[vid]
            data[measure][gender][stat] = Dict("years" => d.years, "values" => d.values)
        end
    end
end

data_json = JSON3.write(data)
println("Data fetched. Building HTML...")

html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Gender Income Gap &mdash; Inequality Dashboard</title>
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

    main { display: flex; flex-direction: column; gap: 1.5rem; }

    section {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }

    #chart-section { min-height: 640px; }

    .about-section { background: var(--bg); }

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

    .chart-controls {
      padding: 0.6rem 1rem;
      border-bottom: 1px solid var(--border);
      background: var(--bg);
      flex-shrink: 0;
      display: flex;
      align-items: center;
      gap: 1.25rem;
      flex-wrap: wrap;
    }

    .chart-ctrl { display: flex; align-items: center; gap: 0.5rem; }
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

    #chart { flex: 1; min-height: 540px; }

    .prose { flex: 1; padding: 1.5rem 1.75rem; line-height: 1.7; font-size: 0.93rem; overflow: auto; }
  </style>
</head>
<body>

<div class="page" style="padding-bottom: 1rem;">
  <header class="site-header">
    <h1><a href="../index.html">Inequality Dashboard</a></h1>
    <p class="subtitle">Stone Centre on Wealth and Income Inequality | Vancouver School of Economics | University of British Columbia</p>
  </header>

  <p class="breadcrumb"><a href="../index.html">&larr; All categories</a> / <a href="../income.html">Income</a></p>

  <h2 class="post-title">Gender Income Gap</h2>
</div>

<main class="page" style="padding: 1.5rem 1.5rem;">
  <section id="chart-section">
    <div class="section-label">Chart</div>
    <div class="chart-controls">
      <div class="chart-ctrl">
        <span class="chart-ctrl-label">Income Type</span>
        <select id="income-type-select">
          <option value="market">Market</option>
          <option value="total">Total</option>
        </select>
      </div>
      <div class="chart-ctrl">
        <span class="chart-ctrl-label">Statistic</span>
        <select id="statistic-select">
          <option value="mean">Mean</option>
          <option value="median">Median</option>
        </select>
      </div>
      <div class="chart-ctrl">
        <span class="chart-ctrl-label">View</span>
        <select id="view-select">
          <option value="amounts">Amounts</option>
          <option value="gap_pct">Percentage Gap</option>
          <option value="gap_abs">Dollar Gap</option>
        </select>
      </div>
    </div>
    <div id="chart"></div>
  </section>

  <section class="about-section">
    <div class="section-label">About this data</div>
    <div class="prose"></div>
  </section>
</main>

<script>
  const DATA = $(data_json);

  const MEASURE_LABELS = { total: "Total Income", market: "Market Income" };
  const STAT_LABELS = { mean: "Mean", median: "Median" };

  const MEN_COLOR = "#2a78d6";
  const WOMEN_COLOR = "#eb6834";
  const GAP_COLOR = "#e34948";

  var currentIncomeType = "market";
  var currentStatistic = "mean";
  var currentView = "amounts";

  var MARGIN_T = 50, MARGIN_B = 130;

  function seriesFor(measure, gender, statKey) {
    return DATA[measure][gender][statKey];
  }

  function computeGap(measure, statKey, view) {
    var men = seriesFor(measure, "men", statKey);
    var women = seriesFor(measure, "women", statKey);
    var values = men.years.map(function(y, i) {
      var diff = men.values[i] - women.values[i];
      return view === "gap_pct" ? (diff / men.values[i]) * 100 : diff;
    });
    return { years: men.years, values: values };
  }

  function buildTitle(measure, statKey, view) {
    var m = MEASURE_LABELS[measure];
    var s = STAT_LABELS[statKey];
    if (view === "amounts")  return m + " by Gender (" + s + ")";
    if (view === "gap_pct")  return "Gender Gap in " + s + " " + m + " (%)";
    return "Gender Gap in " + s + " " + m + " (\$)";
  }

  function buildTraces(measure, statKey, view) {
    if (view === "amounts") {
      var men = seriesFor(measure, "men", statKey);
      var women = seriesFor(measure, "women", statKey);
      return [
        {
          type: "scatter", mode: "lines", name: "Men",
          x: men.years, y: men.values,
          line: { color: MEN_COLOR, width: 2.5 },
          hovertemplate: "\$%{y:,.0f}<extra>Men</extra>",
        },
        {
          type: "scatter", mode: "lines", name: "Women",
          x: women.years, y: women.values,
          line: { color: WOMEN_COLOR, width: 2.5 },
          hovertemplate: "\$%{y:,.0f}<extra>Women</extra>",
        },
      ];
    }
    var g = computeGap(measure, statKey, view);
    var label = "Gender Gap — " + STAT_LABELS[statKey] + (view === "gap_pct" ? " (%)" : " (\$)");
    var valueFmt = view === "gap_pct" ? "%{y:.1f}%" : "\$%{y:,.0f}";
    return [{
      type: "scatter", mode: "lines", name: label,
      x: g.years, y: g.values,
      line: { color: GAP_COLOR, width: 2.5 },
      hovertemplate: valueFmt + "<extra>" + label + "</extra>",
    }];
  }

  function buildLayout() {
    var el    = document.getElementById("chart");
    var plotH = Math.max((el.offsetHeight || 480) - MARGIN_T - MARGIN_B, 80);
    var noteY = -((MARGIN_B - 15) / plotH);
    var yTitle = currentView === "gap_pct" ? "Percent (%)" : "2024 Constant Dollars (\$)";
    return {
      title: { text: buildTitle(currentIncomeType, currentStatistic, currentView) },
      xaxis: { title: { text: "Year" } },
      yaxis: { title: { text: yTitle } },
      showlegend: currentView === "amounts",
      legend: { x: 0.02, y: 0.98, xanchor: "left", yanchor: "top", bgcolor: "rgba(255,255,255,0.7)", bordercolor: "#ddd", borderwidth: 1 },
      margin: { l: 70, b: MARGIN_B, r: 20, t: MARGIN_T },
      paper_bgcolor: "white",
      plot_bgcolor: "#E5ECF6",
      hovermode: "x unified",
      annotations: [{
        xref: "paper", yref: "paper",
        x: 0.5, y: noteY,
        xanchor: "center", yanchor: "bottom",
        showarrow: false,
        text: "Chart created by the Stone Centre on Wealth and Income Inequality<br>at the Vancouver School of Economics (UBC) using data from Statistics Canada (Canadian Income Survey)",
        font: { size: 9, color: "#b0b0b0" },
      }],
    };
  }

  function rerender() {
    Plotly.react("chart", buildTraces(currentIncomeType, currentStatistic, currentView), buildLayout(), { responsive: true });
  }

  document.getElementById("income-type-select").addEventListener("change", function() {
    currentIncomeType = this.value;
    rerender();
  });

  document.getElementById("statistic-select").addEventListener("change", function() {
    currentStatistic = this.value;
    rerender();
  });

  document.getElementById("view-select").addEventListener("change", function() {
    currentView = this.value;
    rerender();
  });

  Plotly.newPlot("chart", buildTraces(currentIncomeType, currentStatistic, currentView), buildLayout(), { responsive: true });

  // Recompute the attribution note's position whenever the chart div is
  // resized. Debounced to avoid a relayout -> resize -> relayout loop.
  var resizeTimer;
  new ResizeObserver(function() {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(function() {
      Plotly.relayout("chart", buildLayout());
    }, 50);
  }).observe(document.getElementById("chart"));
</script>

</body>
</html>"""

output = joinpath(@__DIR__, "gender_income_gap.html")
write(output, html)
println("Saved -> $output")

if Sys.isapple()
    run(`open $output`)
elseif Sys.iswindows()
    run(`cmd /c start $output`)
else
    run(`xdg-open $output`)
end
