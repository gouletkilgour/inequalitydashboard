using JSON3

# -- Source data ---------------------------------------------------------------
# Primary source (all 10 provinces): Employment and Social Development Canada
# (ESDC), "Historical Minimum Wage Rates in Canada" (general adult rate),
# Open Government Portal, dataset 390ee890-59bb-4f34-a37c-9732781ef8a0,
# resource wages_general-2.csv, downloaded 2026-09-02:
#   https://open.canada.ca/data/en/dataset/390ee890-59bb-4f34-a37c-9732781ef8a0
# This is the same underlying data as the Government of Canada's public-facing
# "Minimum Wage Database": https://minwage-salairemin.service.canada.ca/
#
# Methodology:
#  - This is the GENERAL (basic adult) minimum wage only. It excludes rates
#    that applied only to young/student workers or specific occupations
#    (liquor servers, homeworkers, etc.), which ESDC tracks in a separate file.
#  - Periods where a province set EXPLICITLY SEX-DIFFERENTIATED rates (a lower
#    rate for women than men) are excluded entirely, per user request. Each
#    such province's series starts at the first date a single, sex-neutral
#    general rate took effect:
#      Newfoundland and Labrador: excludes 1965-01-01 to 1970-07-01 (women's/
#        men's rates); series starts 1972-06-01.
#      Nova Scotia: excludes 1965-02-20 to 1971-07-01; series starts 1972-07-01.
#      Ontario: excludes 1965-01-01 to 1965-03-29 (Southern Ontario Zone
#        women's rate below the men's rate); series starts 1965-12-27 (see
#        below - Ontario also had a regional split until that date).
#      Prince Edward Island: excludes 1965-01-01 to 1973-07-01; series starts
#        1974-01-01.
#  - Periods of REGIONAL or SECTORAL variation (a rate that did not cover all
#    workers province-wide - urban vs. non-urban, metropolitan vs. rest of
#    province, or one sector vs. others) are also excluded entirely, rather
#    than picking one of the coexisting rates over the other. Each affected
#    province's series starts at the first date a single rate covered every
#    worker in the province:
#      Alberta: excludes 1965-01-01 to 1966-06-30 (separate urban/non-urban
#        rates); series starts 1966-07-01.
#      New Brunswick: excludes 1965-01-01 to 1967-12-31 (rate applied only to
#        wholesale, retail and manufacturing; other sectors had different,
#        unspecified rates); series starts 1968-01-01.
#      Ontario: excludes 1965-01-01 to 1965-12-26 (Northern Ontario Zone rate
#        below the Southern Zone rate, on top of the sex-differentiated
#        period noted above); series starts 1965-12-27.
#      Quebec: excludes 1965-01-01 to 1971-04-30 (Montreal metropolitan rate
#        above the rest-of-province rate); series starts 1971-05-01.
#      Saskatchewan: excludes 1968-10-01 to 1972-01-01 (metropolitan-area
#        rate above the rest-of-province rate); series starts 1972-01-02.
#    Manitoba's urban/rural split (1965-1966) is handled the same way - its
#    series already started at its first province-wide rate (1966-12-01).
#    British Columbia never had a regional or sectoral split.
#  - Qualifiers like "employees 16 years of age or older" note the general
#    legal working age the rate applied from, not a separate youth sub-rate,
#    so these points are kept as the general rate.
#  - Data is shown only through today (2026-09-02); rates enacted but not yet
#    in effect (e.g., increases scheduled for later in 2026 or in 2027) are
#    excluded. This page does not update automatically for future increases.
#  - Correction: the source CSV lists British Columbia's $17.85 rate under an
#    effective date of 2026-06-01, alongside $18.25 also dated 2026-06-01.
#    Government of Canada news releases confirm $17.85 actually took effect
#    2025-06-01 and $18.25 took effect 2026-06-01; corrected here accordingly.
#      https://news.gov.bc.ca/releases/2025LBR0017-000500
#      https://news.gov.bc.ca/releases/2026LBR0021-000581
# --------------------------------------------------------------------------------

const PROVINCES = [
    "Newfoundland and Labrador",
    "Prince Edward Island",
    "Nova Scotia",
    "New Brunswick",
    "Quebec",
    "Ontario",
    "Manitoba",
    "Saskatchewan",
    "Alberta",
    "British Columbia",
]

const ABBR = Dict(
    "Newfoundland and Labrador" => "NL",
    "Prince Edward Island"      => "PE",
    "Nova Scotia"               => "NS",
    "New Brunswick"             => "NB",
    "Quebec"                    => "QC",
    "Ontario"                   => "ON",
    "Manitoba"                  => "MB",
    "Saskatchewan"              => "SK",
    "Alberta"                   => "AB",
    "British Columbia"          => "BC",
)

# Each entry: (effective_date, rate, note)
const RAW = Dict(
    "Alberta" => [
        ("1966-07-01", 1.00, "First rate to apply province-wide; before this date, Alberta had separate urban (\$1.00) and non-urban (\$0.95) rates, which are excluded here."),
        ("1967-08-01", 1.15, ""),
        ("1968-01-01", 1.25, ""),
        ("1970-04-01", 1.40, ""),
        ("1970-10-01", 1.55, ""),
        ("1973-01-01", 1.75, ""),
        ("1973-10-01", 1.90, ""),
        ("1974-04-01", 2.00, ""),
        ("1975-01-01", 2.25, ""),
        ("1975-07-01", 2.50, ""),
        ("1976-03-01", 2.75, ""),
        ("1977-03-01", 3.00, ""),
        ("1980-05-01", 3.50, ""),
        ("1981-05-01", 3.80, ""),
        ("1988-09-01", 4.50, ""),
        ("1992-04-01", 5.00, ""),
        ("1998-10-01", 5.40, ""),
        ("1999-04-01", 5.65, ""),
        ("1999-10-01", 5.90, ""),
        ("2005-09-01", 7.00, ""),
        ("2007-09-01", 8.00, ""),
        ("2008-04-01", 8.40, ""),
        ("2009-04-01", 8.80, ""),
        ("2011-09-01", 9.40, ""),
        ("2012-09-01", 9.75, ""),
        ("2013-09-01", 9.95, ""),
        ("2014-09-01", 10.20, ""),
        ("2015-10-01", 11.20, ""),
        ("2016-10-01", 12.20, ""),
        ("2017-10-01", 13.60, ""),
        ("2018-10-01", 15.00, ""),
    ],
    "British Columbia" => [
        ("1965-01-01", 1.00, ""),
        ("1967-05-01", 1.10, ""),
        ("1967-11-01", 1.25, ""),
        ("1970-05-04", 1.50, ""),
        ("1972-12-04", 2.00, ""),
        ("1973-12-03", 2.25, ""),
        ("1974-06-03", 2.50, ""),
        ("1975-12-01", 2.75, ""),
        ("1976-01-01", 3.00, ""),
        ("1980-07-01", 3.40, ""),
        ("1980-12-01", 3.65, ""),
        ("1988-07-01", 4.50, ""),
        ("1989-10-01", 4.75, ""),
        ("1990-04-01", 5.00, ""),
        ("1992-02-01", 5.50, ""),
        ("1993-04-01", 6.00, ""),
        ("1995-03-01", 6.50, ""),
        ("1995-10-01", 7.00, ""),
        ("1998-04-01", 7.15, ""),
        ("2000-11-01", 7.60, ""),
        ("2001-11-01", 8.00, ""),
        ("2011-05-01", 8.75, ""),
        ("2011-11-01", 9.50, ""),
        ("2012-05-01", 10.25, ""),
        ("2015-09-15", 10.45, ""),
        ("2016-09-15", 10.85, ""),
        ("2017-09-15", 11.35, ""),
        ("2018-06-01", 12.65, ""),
        ("2019-06-01", 13.85, ""),
        ("2020-06-01", 14.60, ""),
        ("2021-06-01", 15.20, ""),
        ("2022-06-01", 15.65, ""),
        ("2023-06-01", 16.75, ""),
        ("2024-06-01", 17.40, ""),
        ("2025-06-01", 17.85, "Date corrected from the source file, which mislabeled this rate as effective 2026-06-01; confirmed via BC government news release 2025LBR0017-000500."),
        ("2026-06-01", 18.25, ""),
    ],
    "Manitoba" => [
        ("1966-12-01", 1.00, "Rural/urban rate distinction (in effect since 1965) ended on this date."),
        ("1967-12-01", 1.10, ""),
        ("1968-04-01", 1.15, ""),
        ("1968-08-01", 1.20, ""),
        ("1968-12-01", 1.25, ""),
        ("1969-12-01", 1.35, ""),
        ("1970-10-01", 1.50, ""),
        ("1971-11-01", 1.65, ""),
        ("1972-10-01", 1.75, ""),
        ("1973-10-01", 1.90, ""),
        ("1974-07-01", 2.15, ""),
        ("1975-01-01", 2.30, ""),
        ("1975-10-01", 2.60, ""),
        ("1976-09-01", 2.95, ""),
        ("1979-07-01", 3.05, ""),
        ("1980-01-01", 3.15, ""),
        ("1981-03-01", 3.35, ""),
        ("1981-09-01", 3.55, ""),
        ("1982-07-01", 4.00, ""),
        ("1985-01-01", 4.30, ""),
        ("1987-04-01", 4.50, ""),
        ("1987-09-01", 4.70, ""),
        ("1991-03-01", 5.00, ""),
        ("1995-07-01", 5.25, ""),
        ("1996-01-01", 5.40, ""),
        ("1999-04-01", 6.00, ""),
        ("2001-04-01", 6.25, ""),
        ("2002-04-01", 6.50, ""),
        ("2003-04-01", 6.75, ""),
        ("2004-04-01", 7.00, ""),
        ("2005-04-01", 7.25, ""),
        ("2006-04-01", 7.60, ""),
        ("2007-04-01", 8.00, ""),
        ("2008-04-01", 8.50, ""),
        ("2009-05-01", 8.75, ""),
        ("2009-10-01", 9.00, ""),
        ("2010-10-01", 9.50, ""),
        ("2011-10-01", 10.00, ""),
        ("2012-10-01", 10.25, ""),
        ("2013-10-01", 10.45, ""),
        ("2014-10-01", 10.70, ""),
        ("2015-10-01", 11.00, ""),
        ("2017-10-01", 11.15, ""),
        ("2018-10-01", 11.35, ""),
        ("2019-10-01", 11.65, ""),
        ("2020-10-01", 11.90, ""),
        ("2021-10-01", 11.95, ""),
        ("2022-10-01", 13.50, ""),
        ("2023-04-01", 14.15, ""),
        ("2024-10-01", 15.80, ""),
        ("2025-10-01", 16.00, ""),
    ],
    "New Brunswick" => [
        ("1968-01-01", 1.00, "First rate to cover all sectors; from 1965 it applied only to wholesale, retail and manufacturing (other sectors had different, unspecified rates), which is excluded here."),
        ("1970-01-01", 1.15, ""),
        ("1971-09-01", 1.25, ""),
        ("1972-03-01", 1.40, ""),
        ("1973-01-01", 1.50, ""),
        ("1974-01-01", 1.75, ""),
        ("1974-07-01", 1.90, ""),
        ("1975-01-01", 2.15, ""),
        ("1975-07-01", 2.30, ""),
        ("1976-06-01", 2.55, ""),
        ("1976-11-01", 2.80, ""),
        ("1980-07-01", 3.05, ""),
        ("1980-10-01", 3.35, ""),
        ("1982-10-01", 3.80, ""),
        ("1986-09-15", 4.00, ""),
        ("1989-04-01", 4.25, ""),
        ("1989-10-01", 4.50, ""),
        ("1990-10-01", 4.75, ""),
        ("1991-10-01", 5.00, ""),
        ("1996-01-01", 5.25, ""),
        ("1996-07-01", 5.50, ""),
        ("2000-01-01", 5.75, ""),
        ("2001-07-01", 5.90, ""),
        ("2002-08-01", 6.00, ""),
        ("2004-01-01", 6.20, ""),
        ("2005-01-01", 6.30, ""),
        ("2006-01-01", 6.50, ""),
        ("2006-07-01", 6.70, ""),
        ("2007-01-05", 7.00, ""),
        ("2007-07-01", 7.25, ""),
        ("2008-03-31", 7.75, ""),
        ("2009-09-01", 8.25, ""),
        ("2010-04-01", 8.50, ""),
        ("2010-09-01", 9.00, ""),
        ("2011-04-01", 9.50, ""),
        ("2011-09-01", 10.00, ""),
        ("2014-12-31", 10.30, ""),
        ("2016-04-01", 10.65, ""),
        ("2017-04-01", 11.00, ""),
        ("2018-04-01", 11.25, ""),
        ("2019-04-01", 11.50, ""),
        ("2020-04-01", 11.70, ""),
        ("2021-04-01", 11.75, ""),
        ("2022-04-01", 12.75, ""),
        ("2022-10-01", 13.75, ""),
        ("2023-04-01", 14.75, ""),
        ("2024-04-01", 15.30, ""),
        ("2025-04-01", 15.65, ""),
        ("2026-04-01", 15.90, ""),
    ],
    "Newfoundland and Labrador" => [
        ("1972-06-01", 1.40, "First sex-neutral general rate; prior rates (from 1965) were set separately for men and women and are excluded here."),
        ("1974-01-01", 1.80, ""),
        ("1974-07-01", 2.00, ""),
        ("1975-01-01", 2.20, ""),
        ("1976-01-01", 2.50, ""),
        ("1979-06-01", 2.80, ""),
        ("1980-07-01", 3.15, ""),
        ("1981-03-31", 3.45, ""),
        ("1983-01-01", 3.75, ""),
        ("1985-01-01", 4.00, ""),
        ("1988-04-01", 4.25, ""),
        ("1991-04-01", 4.75, ""),
        ("1996-09-01", 5.00, ""),
        ("1997-04-01", 5.25, ""),
        ("1999-10-01", 5.50, ""),
        ("2002-05-01", 5.75, ""),
        ("2002-11-01", 6.00, ""),
        ("2005-06-01", 6.25, ""),
        ("2006-01-01", 6.50, ""),
        ("2006-06-01", 6.75, ""),
        ("2007-01-01", 7.00, ""),
        ("2007-10-01", 7.50, ""),
        ("2008-04-01", 8.00, ""),
        ("2009-01-01", 8.50, ""),
        ("2009-07-01", 9.00, ""),
        ("2010-01-01", 9.50, ""),
        ("2010-07-01", 10.00, ""),
        ("2014-10-01", 10.25, ""),
        ("2015-10-01", 10.50, ""),
        ("2017-04-01", 10.75, ""),
        ("2017-10-01", 11.00, ""),
        ("2018-04-01", 11.15, ""),
        ("2019-04-01", 11.40, ""),
        ("2020-04-01", 11.65, ""),
        ("2020-10-01", 12.15, ""),
        ("2021-04-01", 12.50, ""),
        ("2021-10-01", 12.75, ""),
        ("2022-04-01", 13.20, ""),
        ("2022-10-01", 13.70, ""),
        ("2023-04-01", 14.50, ""),
        ("2023-10-01", 15.00, ""),
        ("2024-04-01", 15.60, ""),
        ("2025-04-01", 16.00, ""),
        ("2026-04-01", 16.35, ""),
    ],
    "Nova Scotia" => [
        ("1972-07-01", 1.55, "First sex-neutral general rate; prior rates (from 1965) were set separately for men and women, and varied by town, and are excluded here."),
        ("1973-07-01", 1.65, ""),
        ("1974-07-01", 1.80, ""),
        ("1974-10-01", 2.00, ""),
        ("1975-01-01", 2.20, ""),
        ("1975-03-01", 2.25, ""),
        ("1976-01-01", 2.50, ""),
        ("1977-01-01", 2.75, ""),
        ("1980-10-01", 3.00, ""),
        ("1981-10-01", 3.30, ""),
        ("1982-10-01", 3.75, ""),
        ("1985-01-01", 4.00, ""),
        ("1989-01-01", 4.50, ""),
        ("1991-10-01", 4.75, ""),
        ("1992-01-01", 5.00, ""),
        ("1993-01-01", 5.15, ""),
        ("1996-10-01", 5.35, ""),
        ("1997-02-01", 5.50, ""),
        ("1999-10-01", 5.60, ""),
        ("2000-10-01", 5.70, ""),
        ("2001-10-01", 5.80, ""),
        ("2002-10-01", 6.00, ""),
        ("2003-10-01", 6.25, ""),
        ("2004-04-01", 6.50, ""),
        ("2005-10-01", 6.80, ""),
        ("2006-04-01", 7.15, ""),
        ("2007-05-01", 7.60, ""),
        ("2008-05-01", 8.10, ""),
        ("2009-04-01", 8.60, ""),
        ("2010-04-01", 9.20, ""),
        ("2010-10-01", 9.65, ""),
        ("2011-10-01", 10.00, ""),
        ("2012-04-01", 10.15, ""),
        ("2013-04-01", 10.30, ""),
        ("2014-04-01", 10.40, ""),
        ("2015-04-01", 10.60, ""),
        ("2016-04-01", 10.70, ""),
        ("2017-04-01", 10.85, ""),
        ("2018-04-01", 11.00, ""),
        ("2019-04-01", 11.55, ""),
        ("2020-04-01", 12.55, ""),
        ("2021-04-01", 12.95, ""),
        ("2022-04-01", 13.35, ""),
        ("2022-10-01", 13.60, ""),
        ("2023-04-01", 14.50, ""),
        ("2023-10-01", 15.00, ""),
        ("2024-04-01", 15.20, ""),
        ("2025-04-01", 15.70, ""),
        ("2025-10-01", 16.50, ""),
        ("2026-04-01", 16.75, ""),
    ],
    "Ontario" => [
        ("1965-12-27", 1.00, "First rate to apply province-wide. Prior rates are excluded here: the Southern Ontario Zone had sex-differentiated men's/women's rates until March 30, 1965, and the Northern Ontario Zone had a lower rate (\$0.90) than the Southern Zone until this date."),
        ("1969-01-01", 1.30, ""),
        ("1970-10-01", 1.50, ""),
        ("1971-04-01", 1.65, ""),
        ("1973-02-01", 1.80, ""),
        ("1974-01-01", 2.00, ""),
        ("1974-10-01", 2.25, ""),
        ("1975-05-01", 2.40, ""),
        ("1976-03-15", 2.65, ""),
        ("1978-08-01", 2.85, ""),
        ("1979-01-01", 3.00, ""),
        ("1981-03-31", 3.30, ""),
        ("1981-10-01", 3.50, ""),
        ("1984-03-01", 3.85, ""),
        ("1984-10-01", 4.00, ""),
        ("1986-10-01", 4.35, ""),
        ("1987-10-01", 4.55, ""),
        ("1988-10-01", 4.75, ""),
        ("1989-10-01", 5.00, ""),
        ("1990-10-01", 5.40, ""),
        ("1991-11-01", 6.00, ""),
        ("1992-11-01", 6.35, ""),
        ("1994-01-01", 6.70, ""),
        ("1995-01-01", 6.85, ""),
        ("2004-02-01", 7.15, ""),
        ("2005-02-01", 7.45, ""),
        ("2006-02-01", 7.75, ""),
        ("2007-02-01", 8.00, ""),
        ("2008-03-31", 8.75, ""),
        ("2009-03-31", 9.50, ""),
        ("2010-03-31", 10.25, ""),
        ("2014-06-01", 11.00, ""),
        ("2015-10-01", 11.25, ""),
        ("2016-10-01", 11.40, ""),
        ("2017-10-01", 11.60, ""),
        ("2018-01-01", 14.00, ""),
        ("2020-10-01", 14.25, ""),
        ("2021-10-01", 14.35, ""),
        ("2022-01-01", 15.00, ""),
        ("2022-10-01", 15.50, ""),
        ("2024-10-01", 17.20, ""),
        ("2025-10-01", 17.60, ""),
    ],
    "Prince Edward Island" => [
        ("1974-01-01", 1.65, "First sex-neutral general rate; prior rates (from 1965) were set separately for men and women and are excluded here."),
        ("1974-07-01", 1.75, ""),
        ("1975-01-01", 2.05, ""),
        ("1975-10-01", 2.30, ""),
        ("1976-07-01", 2.50, ""),
        ("1977-07-01", 2.70, ""),
        ("1978-11-26", 2.75, ""),
        ("1980-07-01", 3.00, ""),
        ("1981-07-01", 3.30, ""),
        ("1982-10-01", 3.75, ""),
        ("1985-10-01", 4.00, ""),
        ("1988-10-01", 4.25, ""),
        ("1989-04-01", 4.50, ""),
        ("1991-04-01", 4.75, ""),
        ("1996-09-01", 5.15, ""),
        ("1997-09-01", 5.40, ""),
        ("2000-01-01", 5.60, ""),
        ("2001-01-01", 5.80, ""),
        ("2002-01-01", 6.00, ""),
        ("2003-01-01", 6.25, ""),
        ("2004-01-01", 6.50, ""),
        ("2005-01-01", 6.80, ""),
        ("2006-04-01", 7.15, ""),
        ("2007-04-01", 7.50, ""),
        ("2008-05-01", 7.75, ""),
        ("2008-10-01", 8.00, ""),
        ("2009-06-01", 8.20, ""),
        ("2009-10-01", 8.40, ""),
        ("2010-06-01", 8.70, ""),
        ("2010-10-01", 9.00, ""),
        ("2011-06-01", 9.30, ""),
        ("2011-10-01", 9.60, ""),
        ("2012-04-01", 10.00, ""),
        ("2014-06-01", 10.20, ""),
        ("2014-10-01", 10.35, ""),
        ("2015-07-01", 10.50, ""),
        ("2016-06-01", 10.75, ""),
        ("2016-10-01", 11.00, ""),
        ("2017-04-01", 11.25, ""),
        ("2018-04-01", 11.55, ""),
        ("2019-04-01", 12.25, ""),
        ("2020-04-01", 12.85, ""),
        ("2021-04-01", 13.00, ""),
        ("2022-04-01", 13.70, ""),
        ("2023-01-01", 14.50, ""),
        ("2023-10-01", 15.00, ""),
        ("2024-10-01", 16.00, ""),
        ("2025-10-01", 16.50, ""),
        ("2026-04-01", 17.00, ""),
    ],
    "Quebec" => [
        ("1971-05-01", 1.45, "First rate to apply province-wide; from 1965 Quebec had a higher rate in the Montreal metropolitan area than elsewhere in the province, which is excluded here."),
        ("1971-11-01", 1.50, ""),
        ("1972-08-01", 1.60, ""),
        ("1972-11-01", 1.65, ""),
        ("1973-05-01", 1.70, ""),
        ("1973-11-01", 1.85, ""),
        ("1974-05-01", 2.10, ""),
        ("1974-11-01", 2.30, ""),
        ("1975-06-01", 2.60, ""),
        ("1975-12-01", 2.80, ""),
        ("1976-07-01", 2.87, ""),
        ("1977-01-01", 3.00, ""),
        ("1977-07-01", 3.15, ""),
        ("1978-01-01", 3.27, ""),
        ("1978-10-01", 3.37, ""),
        ("1979-04-01", 3.47, ""),
        ("1980-04-01", 3.65, ""),
        ("1981-04-01", 3.85, ""),
        ("1981-10-01", 4.00, ""),
        ("1986-10-01", 4.35, ""),
        ("1987-10-01", 4.55, ""),
        ("1988-10-01", 4.75, ""),
        ("1989-10-01", 5.00, ""),
        ("1990-10-01", 5.30, ""),
        ("1991-10-01", 5.55, ""),
        ("1992-10-01", 5.70, ""),
        ("1993-10-01", 5.85, ""),
        ("1994-10-01", 6.00, ""),
        ("1995-10-01", 6.45, ""),
        ("1996-10-01", 6.70, ""),
        ("1997-10-01", 6.80, ""),
        ("1998-10-01", 6.90, ""),
        ("2001-02-01", 7.00, ""),
        ("2002-10-01", 7.20, ""),
        ("2003-02-01", 7.30, ""),
        ("2004-05-01", 7.45, ""),
        ("2005-05-01", 7.60, ""),
        ("2006-05-01", 7.75, ""),
        ("2007-05-01", 8.00, ""),
        ("2008-05-01", 8.50, ""),
        ("2009-05-01", 9.00, ""),
        ("2010-05-01", 9.50, ""),
        ("2011-05-01", 9.65, ""),
        ("2012-05-01", 9.90, ""),
        ("2013-05-01", 10.15, ""),
        ("2014-05-01", 10.35, ""),
        ("2015-05-01", 10.55, ""),
        ("2016-05-01", 10.75, ""),
        ("2017-05-01", 11.25, ""),
        ("2018-05-01", 12.00, ""),
        ("2019-05-01", 12.50, ""),
        ("2020-05-01", 13.10, ""),
        ("2021-05-01", 13.50, ""),
        ("2022-05-01", 14.25, ""),
        ("2023-05-01", 15.25, ""),
        ("2024-05-01", 15.75, ""),
        ("2025-05-01", 16.10, ""),
        ("2026-05-01", 16.60, ""),
    ],
    "Saskatchewan" => [
        ("1972-01-02", 1.70, "First rate to apply province-wide; from 1968 Saskatchewan had a higher rate in metropolitan areas than elsewhere in the province, which is excluded here."),
        ("1972-07-01", 1.75, ""),
        ("1973-12-01", 2.00, ""),
        ("1974-07-02", 2.25, ""),
        ("1975-03-31", 2.50, ""),
        ("1976-01-01", 2.80, ""),
        ("1977-01-01", 3.00, ""),
        ("1978-01-31", 3.15, ""),
        ("1978-06-30", 3.25, ""),
        ("1979-10-01", 3.50, ""),
        ("1980-05-01", 3.65, ""),
        ("1981-01-01", 3.85, ""),
        ("1981-07-01", 4.00, ""),
        ("1982-01-01", 4.25, ""),
        ("1985-08-01", 4.50, ""),
        ("1990-01-01", 4.75, ""),
        ("1990-07-01", 5.00, ""),
        ("1992-12-01", 5.35, ""),
        ("1996-12-01", 5.60, ""),
        ("1999-01-01", 6.00, ""),
        ("2002-05-01", 6.35, ""),
        ("2002-11-01", 6.65, ""),
        ("2005-09-01", 7.05, ""),
        ("2006-03-01", 7.55, ""),
        ("2007-03-01", 7.95, ""),
        ("2008-01-01", 8.25, ""),
        ("2008-05-01", 8.60, ""),
        ("2009-05-01", 9.25, ""),
        ("2011-09-01", 9.50, ""),
        ("2012-12-01", 10.00, ""),
        ("2014-10-01", 10.20, ""),
        ("2015-10-01", 10.50, ""),
        ("2016-10-01", 10.72, ""),
        ("2017-10-01", 10.96, ""),
        ("2018-10-01", 11.06, ""),
        ("2019-10-01", 11.32, ""),
        ("2020-10-01", 11.45, ""),
        ("2021-10-01", 11.81, ""),
        ("2022-10-01", 13.00, ""),
        ("2024-10-01", 15.00, ""),
        ("2025-10-01", 15.35, ""),
    ],
)

data = Dict{String, Any}()
for prov in PROVINCES
    rows = RAW[prov]
    data[prov] = Dict(
        "dates" => [r[1] for r in rows],
        "rates" => [r[2] for r in rows],
        "notes" => [r[3] for r in rows],
    )
end

data_json = JSON3.write(data)
abbr_json = JSON3.write(ABBR)
provinces_json = JSON3.write(PROVINCES)

println("Data assembled. Building HTML...")

html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Provincial Minimum Wages &mdash; Inequality Dashboard</title>
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
      min-width: 8.5em;
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
    .rank-row.rank-average { font-style: italic; }

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

  <h2 class="post-title">Provincial Minimum Wages</h2>
</div>

<main class="page" style="padding: 1.5rem 1.5rem;">
  <section>
    <div class="section-label">Chart</div>
    <div id="chart"></div>
  </section>

  <section id="rankings">
    <div class="section-label">Provincial Rankings</div>
    <div class="rank-controls">
      <div class="rank-slider-row">
        <span class="rank-ctrl-label">Date</span>
        <input type="range" id="rank-slider" />
        <span id="rank-slider-date" class="rank-date-value"></span>
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
  const ABBR = $(abbr_json);
  const PROVINCES = $(provinces_json);
  const TODAY = "2026-09-02";
  const AVERAGE_NAME = "Average";

  const HIGHLIGHT_COLOR = "#2a78d6";
  const AVERAGE_HIGHLIGHT_COLOR = "#e34948";
  const MUTED_COLOR = "#c3c2b7";
  const AVERAGE_COLOR = "#333333";

  // The latest of the ten provinces' series-start dates (Prince Edward
  // Island's, 1974-01-01). The chart starts here for every province, so
  // all ten (and the average) are shown over the same,
  // consistent span rather than each starting at its own earliest date.
  const DISPLAY_START = PROVINCES.map(function(p) { return DATA[p].dates[0]; }).sort().pop();

  var currentProvince = AVERAGE_NAME;

  // Value in effect on `date`, per the step function defined by (dates, rates)
  // (dates assumed sorted ascending). Returns undefined if `date` precedes the
  // series' first entry.
  function stepValueAt(dates, rates, date) {
    var v;
    for (var i = 0; i < dates.length; i++) {
      if (dates[i] <= date) { v = rates[i]; } else { break; }
    }
    return v;
  }

  // A province's full sourced series (which may start earlier than
  // DISPLAY_START), trimmed to start at DISPLAY_START - synthesizing a
  // starting point holding whatever rate was already in effect on that date,
  // if the province didn't happen to change rates exactly then - and then
  // extended with one extra point at TODAY (holding the last known rate) if
  // its last recorded change predates today, so the line visibly continues
  // through the present instead of appearing to end.
  function displaySeries(prov) {
    var d = DATA[prov];
    var dates = [], rates = [], notes = [];
    if (d.dates.indexOf(DISPLAY_START) === -1) {
      var lastChange = stepValueAt(d.dates, d.dates, DISPLAY_START);
      dates.push(DISPLAY_START);
      rates.push(stepValueAt(d.dates, d.rates, DISPLAY_START));
      notes.push("In effect since " + lastChange + "; series shown from " + DISPLAY_START + " onward for consistency across all provinces.");
    }
    d.dates.forEach(function(dt, i) {
      if (dt >= DISPLAY_START) { dates.push(dt); rates.push(d.rates[i]); notes.push(d.notes[i]); }
    });
    var lastDate = dates[dates.length - 1];
    if (lastDate < TODAY) {
      dates.push(TODAY);
      rates.push(rates[rates.length - 1]);
      notes.push("Rate unchanged since " + lastDate + ".");
    }
    return { dates: dates, rates: rates, notes: notes };
  }

  // Unweighted mean of all ten provinces' rates, computed at every date any
  // province's rate changes, from DISPLAY_START (once every province has a
  // general rate in effect) through today.
  function computeAverageSeries() {
    var dateSet = {};
    PROVINCES.forEach(function(p) {
      DATA[p].dates.forEach(function(dt) { if (dt >= DISPLAY_START) { dateSet[dt] = true; } });
    });
    dateSet[DISPLAY_START] = true;
    dateSet[TODAY] = true;
    var dates = Object.keys(dateSet).sort();
    var rates = dates.map(function(dt) {
      var vals = PROVINCES.map(function(p) { return stepValueAt(DATA[p].dates, DATA[p].rates, dt); })
                           .filter(function(v) { return v !== undefined; });
      return vals.reduce(function(a, b) { return a + b; }, 0) / vals.length;
    });
    return { dates: dates, rates: rates, notes: dates.map(function() { return ""; }) };
  }

  const AVERAGE_SERIES = computeAverageSeries();

  var MARGIN_T = 50, MARGIN_B = 130;

  function buildLayout() {
    var el    = document.getElementById("chart");
    var plotH = Math.max((el.offsetHeight || 480) - MARGIN_T - MARGIN_B, 80);
    var noteY = -((MARGIN_B - 15) / plotH);
    return {
      title: { text: "Provincial Minimum Wages - Canada" },
      xaxis: { title: { text: "Year" } },
      yaxis: { title: { text: "Hourly Minimum Wage (Nominal \$ CAD)" } },
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
        text: "Chart created by the Stone Centre on Wealth and Income Inequality<br>at the Vancouver School of Economics (UBC) using data from Employment and Social Development Canada",
        font: { size: 9, color: "#b0b0b0" },
      }],
    };
  }

  function buildTraces(selected) {
    var traces = PROVINCES.map(function(prov) {
      var isSel = prov === selected;
      var d = displaySeries(prov);
      return {
        type: "scatter",
        mode: "lines",
        name: prov,
        x: d.dates,
        y: d.rates,
        line: { shape: "hv", color: isSel ? HIGHLIGHT_COLOR : MUTED_COLOR, width: isSel ? 3 : 1.5 },
        opacity: isSel ? 1 : 0.55,
        customdata: d.notes.map(function(n) { return n || ""; }),
        hovertemplate: isSel
          ? (prov + "<br>%{x}<br>\$%{y:.2f}/hr<br>%{customdata}<extra></extra>")
          : (prov + "<br>%{x}<br>\$%{y:.2f}/hr<extra></extra>"),
        hoverinfo: isSel ? undefined : "skip",
      };
    });

    var avgSel = selected === AVERAGE_NAME;
    traces.push({
      type: "scatter",
      mode: "lines",
      name: AVERAGE_NAME,
      x: AVERAGE_SERIES.dates,
      y: AVERAGE_SERIES.rates,
      line: { shape: "hv", color: avgSel ? AVERAGE_HIGHLIGHT_COLOR : AVERAGE_COLOR, width: avgSel ? 3 : 2, dash: avgSel ? "solid" : "dot" },
      opacity: 1,
      hovertemplate: AVERAGE_NAME + "<br>%{x}<br>\$%{y:.2f}/hr<extra></extra>",
    });

    return traces.sort(function(a, b) {
      // Draw the selected (highlighted) trace last so it renders on top.
      return (a.name === selected ? 1 : 0) - (b.name === selected ? 1 : 0);
    });
  }

  function valueAt(name, date) {
    if (name === AVERAGE_NAME) { return stepValueAt(AVERAGE_SERIES.dates, AVERAGE_SERIES.rates, date); }
    return stepValueAt(DATA[name].dates, DATA[name].rates, date);
  }

  // Every date the ranking can actually change: the union of all ten
  // provinces' rate-change dates (same set AVERAGE_SERIES is computed over),
  // from DISPLAY_START through today. The ranking slider steps through
  // these rather than raw calendar days, since the ranking is a step
  // function that's only ever different at one of these dates.
  const SLIDER_DATES = AVERAGE_SERIES.dates;

  const MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  function formatDate(dateStr) {
    var p = dateStr.split("-");
    return MONTH_NAMES[parseInt(p[1], 10) - 1] + " " + parseInt(p[2], 10) + ", " + p[0];
  }

  var rankDateIndex = SLIDER_DATES.length - 1;

  function renderRanking() {
    var date = SLIDER_DATES[rankDateIndex];
    document.getElementById("rank-slider-date").textContent = formatDate(date);

    var entries = PROVINCES.concat([AVERAGE_NAME]).map(function(name) {
      return { name: name, value: valueAt(name, date) };
    }).sort(function(a, b) { return b.value - a.value; });

    document.getElementById("rank-list").innerHTML = entries.map(function(e, i) {
      var cls = "rank-row"
              + (e.name === currentProvince ? " rank-active" : "")
              + (e.name === AVERAGE_NAME ? " rank-average" : "");
      return '<div class="' + cls + '" onclick="selectProvince(\\'' + e.name + '\\')">'
           + '<span class="rank-num">' + (i + 1) + '</span>'
           + '<span class="rank-name">' + e.name + '</span>'
           + '<span class="rank-val">\$' + e.value.toFixed(2) + '</span>'
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
  sliderEl.max = SLIDER_DATES.length - 1;
  sliderEl.value = rankDateIndex;
  sliderEl.addEventListener("input", function() {
    rankDateIndex = parseInt(this.value, 10);
    renderRanking();
  });

  Plotly.newPlot("chart", buildTraces(currentProvince), buildLayout(), { responsive: true });
  renderRanking();

  document.getElementById("chart").on("plotly_click", function(evt) {
    if (evt.points && evt.points.length) {
      selectProvince(evt.points[0].data.name);
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

output = joinpath(@__DIR__, "minimum_wage_by_province.html")
write(output, html)
println("Saved -> $output")

if Sys.isapple()
    run(`open $output`)
elseif Sys.iswindows()
    run(`cmd /c start $output`)
else
    run(`xdg-open $output`)
end
