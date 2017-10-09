using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;
using Toybox.UserProfile as UserProfile;

//! @author Indrik myneur -  Many thanks to Roelof Koelewijn for a hr gauge code
class RunningTrends extends App.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new RunningTrendsView()];
    }
}

//! skeleton by @author Konrad Paumann, HeartRateZones by @author Roelof Koelewijn
//! design, charts and layout by Indrik myneur
class RunningTrendsView extends Ui.DataField {
    hidden var referenceDistance = 1000;
    hidden var distanceString = "km";
    hidden var lapPaceStr;
    hidden var distanceUnits = System.UNIT_METRIC;
    hidden var showLapMetrics = false;

    hidden var textColor = Graphics.COLOR_BLACK;
    hidden var backgroundColor = Graphics.COLOR_WHITE;
    hidden var darkColor = Graphics.COLOR_DK_GRAY;
    hidden var lightColor = Graphics.COLOR_LT_GRAY;

    // data for charts and averages
    hidden var paceChartData = new DataQueue(5);
    hidden var hrChartData = new DataQueue(60);
    hidden var lastHrData = new DataQueue(30);

    // metrics
    hidden var avgPace = 0;
    hidden var lapAvgPace = 0;
    hidden var lastLapStartTimer = 0;
    hidden var lastLapStartDistance = 0;
    hidden var currentPace = 0;
    hidden var hr = 0;
    hidden var distance = 0;
    hidden var elapsedTime = 0;

    // heart rate zones
    hidden var zoneMaxLimits = [113, 139, 155, 165, 174, 200];

    hidden var zoneColor = [
        Graphics.COLOR_TRANSPARENT,
        Graphics.COLOR_LT_GRAY,
        Graphics.COLOR_BLUE,
        Graphics.COLOR_GREEN,
        Graphics.COLOR_ORANGE,
        Graphics.COLOR_RED,
        Graphics.COLOR_RED
    ];

    function initialize() {
        DataField.initialize();

        if (Application.getApp().getProperty("showLapMetrics") != null) {
            showLapMetrics = Application.getApp().getProperty("showLapMetrics");
        }
        setDeviceSettingsDependentVariables();
    }

    //! The given info object contains all the current workout
    function compute(info) {
        if (lastHrData.add(info.currentHeartRate) == 0) { // when we filled full length of cirucular buffer
            hrChartData.add(lastHrData.average());
        }

        var avgSpeed = info.averageSpeed ? info.averageSpeed : 0;
        var currentSpeed = info.currentSpeed ? info.currentSpeed : 0;

        elapsedTime = info.timerTime ? info.timerTime : 0;
        hr = info.currentHeartRate ? info.currentHeartRate : 0;
        distance = info.elapsedDistance ? info.elapsedDistance : 0;

        if (avgSpeed == 0) {
            avgPace = 0;
        } else {
            avgPace = (referenceDistance / avgSpeed).toNumber();
        }
        if (currentSpeed == 0) {
            avgSpeed = 0;
        } else {
            currentPace = (referenceDistance / currentSpeed).toNumber();
        }

        if (distance != lastLapStartDistance) {
            lapAvgPace = (elapsedTime - lastLapStartTimer) * referenceDistance / 1000 / (distance - lastLapStartDistance);
            lapAvgPace = lapAvgPace.toNumber();
        }
    }

    function onLayout(dc) {
        //System.println("layout");
        // WTF! If I load the fonts it runs out of memory!
        //fontMidNumbers = Ui.loadResource(Rez.Fonts.MidNumbers);
        //fontBigNumbers = Ui.loadResource(Rez.Fonts.BigNumbers);
        //fontMiniText = Ui.loadResource(Rez.Fonts.MiniText);

        setColors();
        onUpdate(dc);
    }

    function onUpdate(dc) {
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        dc.setColor(backgroundColor, backgroundColor);
        dc.clear();

        drawHrChart(dc, centerX, centerY - 51, 50);
        drawPaceDiff(dc, 115, centerY + 1, 50);
        drawPaceChart(dc, 20, centerY, 50);
        drawZoneBarsArcs(dc, centerY, centerX, centerY, hr);

        //distance
        var d = showLapMetrics ? distance - lastLapStartDistance : distance;
        if (d < 0) {
            d = 0;
        }
        var presentedDistanceValue = d / referenceDistance;
        d = (presentedDistanceValue < 100) ? presentedDistanceValue.format("%.2f") : presentedDistanceValue.format("%.1f");

        drawValues(dc, d);
        drawLabels(dc, d);
    }

    function onTimerLap() {
        paceChartData.add(lapAvgPace);
        lastLapStartTimer = elapsedTime;
        lastLapStartDistance = distance;
    }

    function setDeviceSettingsDependentVariables() {
        distanceUnits = System.getDeviceSettings().distanceUnits;
        if (distanceUnits != System.UNIT_METRIC) {
            referenceDistance = 1610;
            distanceString = "mi";
        } else {
            referenceDistance = 1000;
            distanceString = "km";
        }
        lapPaceStr = Ui.loadResource(Rez.Strings.lapPace);
        if (UserProfile has :getHeartRateZones) {
            zoneMaxLimits = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_RUNNING);
            zoneMaxLimits[0] = zoneMaxLimits[0] - 1; // Garmin returns first limit as zone 1 start, so normalizing to make it comparable
        }
    }

    function setColors() {
        backgroundColor = getBackgroundColor();
        if (backgroundColor == Graphics.COLOR_BLACK) {
            textColor = Graphics.COLOR_WHITE;
            darkColor = Graphics.COLOR_LT_GRAY;
            lightColor = Graphics.COLOR_DK_GRAY;
        } else {
            textColor = Graphics.COLOR_BLACK;
            darkColor = Graphics.COLOR_DK_GRAY;
            lightColor = Graphics.COLOR_LT_GRAY;
        }
    }

    function drawLabels(dc, presentedDistance) {
        var label_font = Graphics.FONT_XTINY;
        var value_font = Graphics.FONT_NUMBER_MEDIUM;
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerOs = 2;
        if (height == 240) {
            centerOs = -4;
        }
        dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width - 23, height / 2 + centerOs, label_font, lapPaceStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2 + dc.getTextWidthInPixels(presentedDistance, value_font) >> 1 + 5, 40, label_font, distanceString, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawValues(dc, presentedDistance) {
        var value_font = Graphics.FONT_NUMBER_MEDIUM;
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerOs = 31;
        if (height == 240) {
            centerOs = 33;
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        var displayHr = hr > 0 ? hr.format("%d") : "--";
        dc.drawText(width - 23, height / 2 - centerOs, value_font, displayHr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width - 23, height / 2 + centerOs, value_font, displayPace(lapAvgPace), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.drawText(width / 2, 33, value_font, presentedDistance, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        //duration
        var d = showLapMetrics ? elapsedTime - lastLapStartTimer : elapsedTime;

        var seconds = d / 1000;
        var minutes = seconds / 60;
        var hours = minutes / 60;
        seconds %= 60;
        minutes %= 60;

        if (hours > 0) {
            d = Lang.format("$1$:$2$:$3$", [hours, minutes.format("%02d"), seconds.format("%02i")]);
        } else {
            d = Lang.format("$1$:$2$", [minutes, seconds.format("%02i")]);
        }
        dc.drawText(width / 2, height - 33, value_font, d, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawPaceDiff(dc, x, y, height) {
        if (currentPace <= 0) {
            dc.fillRectangle(x, y + height >> 1, 8, 8);
        } else {
            var pitch = 10;
            var step = -1;

            // how many times does current pace differ by 15s (1/4 min) from the average pace?
            var diff = (currentPace - lapAvgPace) / 15;
            if (diff < 0) { // slower than average = avg pace < pace
                y += height - 8;
                step = -step;
                pitch = -pitch;
                diff = -diff;
                dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
            } else {
                y += 8;
                dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            }

            if (diff > 3) {
                diff = 3;
            }
            while (diff > 0) {
                dc.fillPolygon([
                    [x, y],
                    [x + 8, y],
                    [x + 4, y + 8 * step]
                ]);
                y += pitch;
                diff--;
            }
        }
    }

    function drawPaceChart(dc, x, y, height) {
        var h;
        var i;
        y += height;

        // max pace for chart scale
        var max = paceChartData.max();
        var min = paceChartData.min();
        if (max == null || max <= 0) {
            return;
        }

        max = max < lapAvgPace ? lapAvgPace : max;
        min = min > lapAvgPace ? lapAvgPace : min;
        max = max < avgPace ? avgPace : max;
        min = min > avgPace ? avgPace : min;

        if (min == max) { // all the numbers are the same
            dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y - height / 2, x + 90, y - height / 2);
            return;
        }
        var scale = height.toFloat() / (max - min);
        dc.setPenWidth(1);
        dc.setColor(lightColor, Graphics.COLOR_TRANSPARENT);
        if (scale > 1) { // do not zoom-in the diffe without limit
            scale = 1;
        }
        // avg pace
        var yL;
        var baseline = height / 2;
        if (max - min < height) {
            if (baseline + max - avgPace > height) {
                baseline = height - (max - avgPace);
            } else if (baseline - (avgPace - min) < 0) {
                baseline = avgPace - min;
            }
        } else {
            baseline = ((avgPace - min) * scale).toNumber();
            yL = (baseline + scale * height / 2).toNumber();
            if (yL < height) {
                dc.drawLine(x, y - yL, x + 90, y - yL);
            }
            yL = (baseline - scale * height / 2).toNumber();
            if (yL > 0) {
                if (yL > 0) {
                    dc.drawLine(x, y - yL, x + 90, y - yL);
                }
            }
        }
        // current pace bar
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);

        // pace history bar chart
        i = 0;
        var pace = lapAvgPace;
        while (pace) {
            h = ((pace - avgPace) * scale).toNumber();
            if (h > 0) {
                dc.fillRectangle(x + 75 - i * 15, y - baseline - h, 13, h); // last laps paces
            } else {
                dc.fillRectangle(x + 75 - i * 15, y - baseline, 13, -h); // last laps paces
            }
            pace = paceChartData.prev(i);
            i++;
        }
        // avg pace line
        dc.setColor(darkColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x, y - baseline, x + 90, y - baseline);
    }

    function drawHrChart(dc, x, y, height) {
        var maxHr = hrChartData.max();
        var h = lastHrData.average(); // the current value
        if (maxHr == null || h == null) {
            return;
        }
        h = h.toNumber();
        var minHr = hrChartData.min();
        if (maxHr < h) {
            maxHr = h;
        }
        if (minHr > h) {
            minHr = h;
        }
        var range = maxHr - minHr;
        while (range < 10) {
            maxHr++;
            minHr--;
            range = maxHr - minHr;
        }

        var v = y + height - height * (h - minHr) / range;
        var i;
        var zoneY = new [zoneMaxLimits.size() + 1];
        var curRange = 0;
        for (i = 1; i < zoneMaxLimits.size(); i++) {
            zoneY[i] = y + height - height * (zoneMaxLimits[i] - minHr) / range;
            if (zoneY[i] > v) {
                curRange = i;
            }
        }
        zoneY[0] = 1000000;
        zoneY[zoneY.size() - 1] = 0;
        dc.setColor(zoneColor[curRange + 1], Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawPoint(x, v);

        i = 0;
        h = hrChartData.prev(i);
        var px = x;
        var py = v;
        while (h) {
            v = y + height - height * (hrChartData.prev(i) - minHr) / range;
            x -= 2;
            if (v > py) { // HR drops y goes up
                while (v > zoneY[curRange] && curRange > 0) {
                    dc.drawLine(px, py, x + 1, zoneY[curRange]);
                    px = x + 1;
                    py = zoneY[curRange] + 1;
                    curRange--;
                    dc.setColor(zoneColor[curRange + 1], Graphics.COLOR_TRANSPARENT);
                }
            } else if (v <= py) { // HR goes up y drops
                while (v <= zoneY[curRange + 1]) {
                    dc.drawLine(px, py, x + 1, zoneY[curRange + 1]);
                    px = x + 1;
                    py = zoneY[curRange + 1];
                    curRange++;
                    dc.setColor(zoneColor[curRange + 1], Graphics.COLOR_TRANSPARENT);
                }
            }
            dc.drawLine(px, py, x, v);
            px = x;
            py = v;
            dc.drawPoint(x, v);
            i += 1;
            h = hrChartData.prev(i);
        }
    }

    function displayPace(pace) {
        if (pace == null || pace == 0) {
            return "0:00";
        }
        var seconds = pace.toNumber();
        var minutes = seconds / 60;
        seconds %= 60;
        return Lang.format("$1$:$2$", [minutes, seconds.format("%02d")]);
    }

    function drawZoneBarsArcs(dc, radius, centerX, centerY, hr) {
        var i = 0;

        while (i < zoneMaxLimits.size() - 1 && hr > zoneMaxLimits[i]) {
            i++;
        }

        if (hr > zoneMaxLimits[i]) {
            hr = zoneMaxLimits[i];
        }

        if (i > 0) { // show zone arc
            var zonedegree = -60 * (hr - zoneMaxLimits[i - 1]) / (zoneMaxLimits[i] - zoneMaxLimits[i - 1]);
            var os = 300 - 60 * i;
            dc.setPenWidth(16);
            dc.setColor(zoneColor[i], Graphics.COLOR_TRANSPARENT);
            dc.drawArc(centerX, centerY, radius, 1, os, os - 60);
            dc.setColor(backgroundColor, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(26);
            dc.drawArc(centerX, centerY, radius, 0, os + zonedegree - 2, os + zonedegree + 2);
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(24);
            dc.drawArc(centerX, centerY, radius, 0, os + zonedegree - 1, os + zonedegree + 1);
        }
    }
}

//! A circular queue core by @author Konrad Paumann, math methods by Indrik myneur
class DataQueue {
    //! the data array.
    var data;
    var maxSize = 0;
    var pos = 0;

    //! precondition: size has to be >= 2
    function initialize(arraySize) {
        data = new [arraySize];
        maxSize = arraySize;
    }

    //! Add an element to the queue.
    function add(element) {
        data[pos] = element;
        pos = (pos + 1) % maxSize;
        return pos;
    }

    function average() {
        var sum = 0;
        var size = 0;
        for (var i = 0; i < maxSize; i++) {
            if (data[i] != null) {
                sum = sum + data[i];
                size++;
            }
        }
        if (size == 0) {
            return null;
        } else {
            return (sum / size.toFloat());
        }
    }

    function max() {
        var max = null;
        for (var i = 0; i < maxSize; i++) {
            if (data[i] == null) {
                continue;
            }
            if (max == null || data[i] > max) {
                max = data[i];
            }
        }
        return max;
    }

    function min() {
        var min = null;
        for (var i = 0; i < maxSize; i++) {
            if (data[i] == null) {
                continue;
            }
            if (min == null || data[i] < min) {
                min = data[i];
            }
        }
        return min;
    }

    function prev(i) {
        if (i >= maxSize) {
            return null;
        }
        return data[(maxSize + pos - i - 1) % maxSize];
    }
}