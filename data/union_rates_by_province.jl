using Pkg
Pkg.add(["HTTP", "JSON3", "Dates"])

using HTTP, JSON3, Dates

# -- StatsCan WDS API ---------------------------------------------------------
# Table  : 14-10-0129-01  "Union status by geography"
#          https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1410012901
# Source : Labour Force Survey (LFS), Statistics Canada. Annual, 1997-2025.
# Series : For each of the 10 provinces plus Canada, for each of two rates
#          (Union coverage rate, Unionization rate), for each of three gender
#          breakdowns (Total, Men+, Women+), the "15 years and over" (i.e.
#          all-ages) series - 66 series in total, each 1997-2025 annual.
#          Excludes the territories (not covered by this table) and the age-
#          band breakdowns (15-24, 25-34, etc., also in the table but not
#          used here).
# Docs   : https://www.statcan.gc.ca/en/developers/wds/user-guide
#
# This script writes union_rates_by_province.html into the same directory it
# lives in (website/data/), already styled to match the rest of the
# Inequality Dashboard site. Re-running it regenerates a ready-to-publish
# page - no manual reskin step.
# -----------------------------------------------------------------------------

const GEOS = [
    "Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia", "New Brunswick",
    "Quebec", "Ontario", "Manitoba", "Saskatchewan", "Alberta", "British Columbia", "Canada",
]

const STATS = ["coverage", "unionization"]
const GENDERS = ["total", "men", "women"]

# vector_ids[stat][gender] => Vector{Int} of length 11, aligned with GEOS
const VECTOR_IDS = Dict(
    "coverage" => Dict(
        "total" => [79918603, 79918693, 79918783, 79918873, 79918963, 79919053, 79919143, 79919233, 79919323, 79919413, 79918513],
        "men"   => [79918609, 79918699, 79918789, 79918879, 79918969, 79919059, 79919149, 79919239, 79919329, 79919419, 79918519],
        "women" => [79918615, 79918705, 79918795, 79918885, 79918975, 79919065, 79919155, 79919245, 79919335, 79919425, 79918525],
    ),
    "unionization" => Dict(
        "total" => [79918639, 79918729, 79918819, 79918909, 79918999, 79919089, 79919179, 79919269, 79919359, 79919449, 79918549],
        "men"   => [79918645, 79918735, 79918825, 79918915, 79919005, 79919095, 79919185, 79919275, 79919365, 79919455, 79918555],
        "women" => [79918651, 79918741, 79918831, 79918921, 79919011, 79919101, 79919191, 79919281, 79919371, 79919461, 79918561],
    ),
)

const N_PERIODS = 29   # 1997-2025 annual
const ENDPOINT   = "https://www150.statcan.gc.ca/t1/wds/rest/getDataFromVectorsAndLatestNPeriods"

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

println("Fetching union coverage / unionization rates from Statistics Canada...")

all_vector_ids = Int[v for stat in STATS for gender in GENDERS for v in VECTOR_IDS[stat][gender]]
raw = fetch_series(all_vector_ids, N_PERIODS)

# Build nested Dict: stat -> gender -> geo -> {years, values}
data = Dict{String, Any}()
for stat in STATS
    data[stat] = Dict{String, Any}()
    for gender in GENDERS
        data[stat][gender] = Dict{String, Any}()
        for (i, geo) in enumerate(GEOS)
            vid = VECTOR_IDS[stat][gender][i]
            d   = raw[vid]
            data[stat][gender][geo] = Dict("years" => d.years, "values" => round.(d.values, digits = 1))
        end
    end
end

data_json = JSON3.write(data)
geos_json = JSON3.write(GEOS)
println("Data fetched. Building HTML...")

html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Union Coverage and Unionization Rates &mdash; Inequality Dashboard</title>
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

    .chart-ctrl {
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }

    .chart-ctrl-label {
      font-size: 0.75rem;
      font-weight: 500;
      color: var(--muted);
    }

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

    .prose { flex: 1; padding: 1.5rem 1.75rem; line-height: 1.7; font-size: 0.93rem; overflow: auto; }
    .prose h2 { font-size: 1rem; font-weight: 600; margin-bottom: 0.75rem; color: var(--text); }
    .prose p { color: var(--text); margin-bottom: 1rem; }
    .prose p:last-child { margin-bottom: 0; }
    .prose strong { color: var(--text); font-weight: 600; }
    .prose a { color: var(--accent, #2a5db0); }

    .rank-controls {
      padding: 0.75rem 1rem 0.65rem;
      border-bottom: 1px solid var(--border);
      background: var(--bg);
      flex-shrink: 0;
    }

    .rank-slider-row {
      display: flex;
      align-items: center;
      gap: 0.6rem;
    }

    .rank-ctrl-label { font-size: 0.75rem; font-weight: 500; color: var(--muted); }

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
      min-width: 3em;
      text-align: right;
      font-variant-numeric: tabular-nums;
    }

    .rank-list { flex: 1; overflow-y: auto; padding: 0.4rem 0; }

    .rank-row {
      display: grid;
      grid-template-columns: 18px 1fr 50px;
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

  <p class="breadcrumb"><a href="../index.html">&larr; All categories</a> / <a href="../unions.html">Unions</a></p>

  <h2 class="post-title">Union Coverage and Unionization Rates</h2>
</div>

<main class="page" style="padding: 1.5rem 1.5rem;">
  <section>
    <div class="section-label">Chart</div>
    <div class="chart-controls">
      <div class="chart-ctrl">
        <span class="chart-ctrl-label">Statistic</span>
        <select id="stat-select">
          <option value="coverage">Union Coverage Rate</option>
          <option value="unionization">Unionization Rate</option>
        </select>
      </div>
      <div class="chart-ctrl">
        <span class="chart-ctrl-label">Gender</span>
        <select id="gender-select">
          <option value="total">Both</option>
          <option value="men">Men</option>
          <option value="women">Women</option>
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
        <span id="rank-slider-year" class="rank-date-value"></span>
      </div>
    </div>
    <div id="rank-list" class="rank-list"></div>
  </section>

  <section class="about-section">
    <div class="section-label">About this data</div>
    <div class="prose"></div>
  </section>
</main>

<script>
  const DATA = $(data_json);
  const GEOS = $(geos_json);
  const YEARS = Array.from({length: 29}, function(_, i) { return 1997 + i; });

  const STAT_LABELS = { coverage: "Union Coverage Rate", unionization: "Unionization Rate" };
  const GENDER_LABELS = { total: "Both", men: "Men", women: "Women" };

  const HIGHLIGHT_COLOR = "#2a78d6";
  const CANADA_HIGHLIGHT_COLOR = "#e34948";
  const MUTED_COLOR = "#c3c2b7";
  const CANADA_COLOR = "#e34948";

  var currentStat = "coverage";
  var currentGender = "total";
  var currentGeo = "Canada";
  var rankYearIndex = YEARS.length - 1;

  var MARGIN_T = 50, MARGIN_B = 130;

  function buildLayout() {
    var el    = document.getElementById("chart");
    var plotH = Math.max((el.offsetHeight || 480) - MARGIN_T - MARGIN_B, 80);
    var noteY = -((MARGIN_B - 15) / plotH);
    return {
      title: { text: STAT_LABELS[currentStat] + " by Province" + (currentGender === "total" ? "" : " (" + GENDER_LABELS[currentGender] + ")") },
      xaxis: { title: { text: "Year" } },
      yaxis: { title: { text: "Percent of Employees (%)" } },
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
        text: "Chart created by the Stone Centre on Wealth and Income Inequality<br>at the Vancouver School of Economics (UBC) using data from Statistics Canada (Labour Force Survey)",
        font: { size: 9, color: "#b0b0b0" },
      }],
    };
  }

  function seriesFor(geo) {
    return DATA[currentStat][currentGender][geo];
  }

  function buildTraces(selected) {
    var traces = GEOS.filter(function(g) { return g !== "Canada"; }).map(function(geo) {
      var isSel = geo === selected;
      var d = seriesFor(geo);
      return {
        type: "scatter",
        mode: "lines",
        name: geo,
        x: d.years,
        y: d.values,
        line: { color: isSel ? HIGHLIGHT_COLOR : MUTED_COLOR, width: isSel ? 3 : 1.5 },
        opacity: isSel ? 1 : 0.55,
        hovertemplate: isSel
          ? (geo + "<br>%{x}<br>%{y:.1f}%<extra></extra>")
          : (geo + "<br>%{x}<br>%{y:.1f}%<extra></extra>"),
        hoverinfo: isSel ? undefined : "skip",
      };
    });

    var caSel = selected === "Canada";
    var ca = seriesFor("Canada");
    traces.push({
      type: "scatter",
      mode: "lines",
      name: "Canada",
      x: ca.years,
      y: ca.values,
      line: { color: caSel ? CANADA_HIGHLIGHT_COLOR : CANADA_COLOR, width: caSel ? 3 : 2, dash: caSel ? "solid" : "dot" },
      opacity: 1,
      hovertemplate: "Canada<br>%{x}<br>%{y:.1f}%<extra></extra>",
    });

    return traces.sort(function(a, b) {
      return (a.name === selected ? 1 : 0) - (b.name === selected ? 1 : 0);
    });
  }

  function renderRanking() {
    var year = YEARS[rankYearIndex];
    document.getElementById("rank-slider-year").textContent = String(year);

    var entries = GEOS.map(function(geo) {
      var d = seriesFor(geo);
      var idx = d.years.indexOf(year);
      return { geo: geo, value: idx >= 0 ? d.values[idx] : null };
    }).filter(function(e) { return e.value !== null; })
      .sort(function(a, b) { return b.value - a.value; });

    document.getElementById("rank-list").innerHTML = entries.map(function(e, i) {
      var cls = "rank-row"
              + (e.geo === currentGeo ? " rank-active" : "")
              + (e.geo === "Canada" ? " rank-canada" : "");
      return '<div class="' + cls + '" onclick="selectGeo(\\'' + e.geo + '\\')">'
           + '<span class="rank-num">' + (i + 1) + '</span>'
           + '<span class="rank-name">' + e.geo + '</span>'
           + '<span class="rank-val">' + e.value.toFixed(1) + '%</span>'
           + '</div>';
    }).join('');
  }

  function selectGeo(geo) {
    currentGeo = geo;
    Plotly.react("chart", buildTraces(geo), buildLayout(), { responsive: true });
    renderRanking();
  }

  function rerenderAll() {
    Plotly.react("chart", buildTraces(currentGeo), buildLayout(), { responsive: true });
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
    rerenderAll();
  });

  document.getElementById("gender-select").addEventListener("change", function() {
    currentGender = this.value;
    rerenderAll();
  });

  Plotly.newPlot("chart", buildTraces(currentGeo), buildLayout(), { responsive: true });
  renderRanking();

  document.getElementById("chart").on("plotly_click", function(evt) {
    if (evt.points && evt.points.length) {
      selectGeo(evt.points[0].data.name);
    }
  });

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

output = joinpath(@__DIR__, "union_rates_by_province.html")
write(output, html)
println("Saved -> $output")

if Sys.isapple()
    run(`open $output`)
elseif Sys.iswindows()
    run(`cmd /c start $output`)
else
    run(`xdg-open $output`)
end
