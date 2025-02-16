# generate-font-comparison.ps1
# Step 1: List all available fonts
Add-Type -AssemblyName System.Drawing
$fonts = [System.Drawing.Text.InstalledFontCollection]::new().Families | ForEach-Object {
    $_.Name
}

# Step 2: Generate HTML content
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Font Comparison Tool</title>
<style>
.link-margin {
    margin-right: 10px;
}
.highlight {
    background-color: yellow;
    font-weight: bold;
}
.comparison-container {
    display: flex;
    flex-direction: column;
}
.text-sample {
    border: 1px solid #ccc;
    text-align: center;
    font-size: 24px;
}
.side-by-side {
    display: flex;
    justify-content: space-around;
}
.above-below {
    display: flex;
    flex-direction: column;
    align-items: center;
}
.overlay {
    position: relative;
}
@keyframes moveUpDown {
    0% { top: 0; }
    50% { top: 5px; }
    100% { top: 0; }
}
.overlay .text-sample {
    position: absolute;
    width: 100%;
    color: rgba(0, 0, 0, 0.8); /* Bright black */
    animation: moveUpDown 2s linear infinite;
}
.overlay .text-sample:nth-child(2) {
    color: rgba(255, 255, 0, 0.8); /* Bright yellow */
    animation-delay: 1s;
}
</style>
</head>
<body>
<h1>Font Comparison Tool</h1>
<div>
<label for="font1">Select Font 1:</label>
<select id="font1" class="font-dropdown">
"@

foreach ($font in $fonts)
{
    $htmlContent += "        <option value=`"$font`">$font</option>`n"
}

$htmlContent += @"
</select>
<label for="font2">Select Font 2:</label>
<select id="font2" class="font-dropdown">
"@

foreach ($font in $fonts)
{
    $htmlContent += "        <option value=`"$font`">$font</option>`n"
}

$htmlContent += @"
</select>
</div>
<div id="suggestion-message1" style="margin-top: 20px;"></div>
<div id="suggestion-message2" style="margin-top: 20px;"></div>
<div class="comparison-container">
<div class="side-by-side">
<div id="sample1" class="text-sample">The quick brown fox jumps over the lazy dog</div>
<div id="sample2" class="text-sample">The quick brown fox jumps over the lazy dog</div>
</div>
<div class="above-below">
<div id="sample3" class="text-sample">The quick brown fox jumps over the lazy dog</div>
<div id="sample4" class="text-sample">The quick brown fox jumps over the lazy dog</div>
</div>
<div class="overlay">
<div id="sample5" class="text-sample">The quick brown fox jumps over the lazy dog</div>
<div id="sample6" class="text-sample">The quick brown fox jumps over the lazy dog</div>
</div>
</div>

<script>
const font1Dropdown = document.getElementById('font1');
const font2Dropdown = document.getElementById('font2');
const sample1 = document.getElementById('sample1');
const sample2 = document.getElementById('sample2');
const sample3 = document.getElementById('sample3');
const sample4 = document.getElementById('sample4');
const sample5 = document.getElementById('sample5');
const sample6 = document.getElementById('sample6');

const sampleText = "The quick brown fox jumps over the lazy dog";
const fontDimensions = {};

const canvas = document.createElement('canvas');
const context = canvas.getContext('2d');

function calculateFontDimensions(fontName) {
    console.time("calculateFontDimensions " + fontName);

    const devicePixelRatio = window.devicePixelRatio || 1;
    canvas.width = canvas.width * devicePixelRatio;
    canvas.height = canvas.height * devicePixelRatio;
    context.scale(devicePixelRatio, devicePixelRatio);

    context.font = "24px " + fontName;
    const metrics = context.measureText(sampleText);
    const dimensions = {
        Width: metrics.width / devicePixelRatio,
        Height: (metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent) / devicePixelRatio
    };
    console.timeEnd("calculateFontDimensions " + fontName);

    let storedFontDimensions = JSON.parse(localStorage.getItem('fontDimensions')) || {};
    storedFontDimensions[fontName] = dimensions;
    localStorage.setItem('fontDimensions', JSON.stringify(storedFontDimensions));

    return dimensions;
}

function loadFontDimensionsFromLocalStorage() {
    return JSON.parse(localStorage.getItem('fontDimensions')) || {};
}

function initializeFontDimensions() {
    console.time('initializeFontDimensions');
    const fontOptions = new Set([...font1Dropdown.options, ...font2Dropdown.options].map(option => option.value));
    const storedFontDimensions = loadFontDimensionsFromLocalStorage();

    fontOptions.forEach(fontName => {
        if (storedFontDimensions[fontName]) {
            fontDimensions[fontName] = storedFontDimensions[fontName];
        } else {
            fontDimensions[fontName] = calculateFontDimensions(fontName);
        }
    });
    console.timeEnd('initializeFontDimensions');
}

function findClosestFonts(selectedFont) {
    const selectedDimensions = fontDimensions[selectedFont];
    const fontDifferences = [];

    for (const [font, dimensions] of Object.entries(fontDimensions)) {
        if (font === selectedFont) continue;
        const difference = Math.abs(dimensions.Width - selectedDimensions.Width) + Math.abs(dimensions.Height - selectedDimensions.Height);
        fontDifferences.push({ font, difference, dimensions });
    }

    fontDifferences.sort((a, b) => a.difference - b.difference);
    return fontDifferences.slice(0, 10); // Return the top 10 closest fonts
}

function updateSuggestionMessage(fontDropdown, sampleElements, suggestionElement, otherDropdown) {
    var selectedFont = fontDropdown.value;
    var dimensions = fontDimensions[selectedFont];
    var closestFonts = findClosestFonts(selectedFont);

    var suggestionHTML = "You have selected the font <span class='highlight'>" + selectedFont + "</span> with a width of " + dimensions.Width + " and a height of " + dimensions.Height + ".";
    suggestionHTML += " <a href='#' class='link-margin' onclick=\"openGoogleSearchTabs('" + selectedFont + "', 'copyright')\">Check Copyright</a>";
    suggestionHTML += " <a href='#' class='link-margin' onclick=\"openGoogleSearchTabs('" + selectedFont + "', 'alternative')\">Check Free Alternative</a><br>";
    suggestionHTML += "The top 10 closest replacement fonts are:<br>";

    closestFonts.forEach(function(fontInfo, index) {
        var fontName = fontInfo.font;
        suggestionHTML += (index + 1) + ". <span class='highlight'>" + fontName + "</span> - Width: " + fontInfo.dimensions.Width + ", Height: " + fontInfo.dimensions.Height;
        suggestionHTML += " <a href='#' class='link-margin' onclick=\"openGoogleSearchTabs('" + fontName + "', 'copyright')\">Check Copyright</a>";
        suggestionHTML += " <a href='#' class='link-margin' onclick=\"openGoogleSearchTabs('" + fontName + "', 'alternative')\">Check Free Alternative</a>";
        suggestionHTML += " <button onclick=\"tryFont('" + fontName + "', '" + otherDropdown.id + "')\">Try it</button><br>";
    });

    suggestionElement.innerHTML = suggestionHTML;

    sampleElements.forEach(function(sample) {
        sample.style.fontFamily = selectedFont;
    });
}

function tryFont(fontName, otherDropdownId) {
    var otherDropdown = document.getElementById(otherDropdownId);
    otherDropdown.value = fontName;
    var event = new Event('change');
    otherDropdown.dispatchEvent(event);
}

function openGoogleSearchTabs(fontName, type) {
    var searchQueries = {
        copyright: [
            fontName + " font copyright",
            fontName + " \u5B57\u4F53 \u7248\u6743"
        ],
        alternative: [
            "free alternative to " + fontName + " font",
            fontName + " \u5B57\u4F53 \u514D\u8D39 \u66FF\u4EE3"
        ]
    };

    searchQueries[type].forEach(function(query) {
        window.open("https://www.google.com/search?q=" + encodeURIComponent(query), '_blank');
    });
}

font1Dropdown.addEventListener('change', () => {
    updateSuggestionMessage(font1Dropdown, [sample1, sample3, sample5], document.getElementById('suggestion-message1'), font2Dropdown);
});

font2Dropdown.addEventListener('change', () => {
    updateSuggestionMessage(font2Dropdown, [sample2, sample4, sample6], document.getElementById('suggestion-message2'), font1Dropdown);
});

window.onload = initializeFontDimensions;
</script>
</body>
</html>
"@

# Step 3: Save the HTML content to a file
$outputFilePath = Join-Path -Path "$env:USERPROFILE\Documents" -ChildPath "font-comparison.html"
$htmlContent | Out-File -FilePath $outputFilePath -Encoding utf8

# Step 4: Open the HTML file in the default web browser
# Check if Chrome is installed and open the HTML file with it
if (Test-Path -Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    Start-Process -FilePath "C:\Program Files\Google\Chrome\Application\chrome.exe" -ArgumentList "$outputFilePath"
} else {
    # If Chrome is not installed, open the file with the default browser
Start-Process $outputFilePath
}
