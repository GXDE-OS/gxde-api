/*
 * Copyright (C) 2014 ~ 2018 Deepin Technology Co., Ltd.
 *
 * Author:     jouyouyun <jouyouwen717@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strings"

	"pkg.deepin.io/dde/api/soundutils"
	"pkg.deepin.io/lib/log"
	"pkg.deepin.io/lib/sound_effect"
)

var logger = log.NewLogger("api/shutdown-sound")

func main() {
	handleSignal()

	cfg, err := soundutils.GetShutdownSoundConfig()
	if err != nil {
		logger.Warning("failed to get shutdown sound config, use default:", err)
		cfg = &soundutils.ShutdownSoundConfig{
			CanPlay: true,
			Theme:   soundutils.GetSoundTheme(),
			Event:   soundutils.EventSystemShutdown,
			Device:  "",
		}
	}

	if !cfg.CanPlay {
		return
	}

	device := cfg.Device
	if device == "" {
		device = findDefaultAlsaDevice()
		logger.Info("device is empty, fallback to:", device)
	}

	err = doPlayShutdownSound(cfg.Theme, cfg.Event, device)
	if err != nil {
		logger.Error("failed to play shutdown sound:", err)
	}
}

func handleSignal() {
	var sigChan = make(chan os.Signal, 2)
	signal.Notify(sigChan, os.Kill, os.Interrupt)
	go func() {
		sig := <-sigChan
		switch sig {
		case os.Kill, os.Interrupt:
			// Nothing to do
			logger.Info("receive signal:", sig.String())
		}
	}()
}

func doPlayShutdownSound(theme, event, device string) error {
	logger.Infof("play theme: %s, event: %s, device: %s", theme, event, device)
	player := sound_effect.NewPlayer(false, sound_effect.PlayBackendALSA)
	err := player.Play(theme, event, device)
	return err
}

func findDefaultAlsaDevice() string {
	out, err := exec.Command("aplay", "-l").CombinedOutput()
	if err != nil {
		logger.Warning("failed to run aplay -l:", string(out))
		return ""
	}

	scanner := bufio.NewScanner(strings.NewReader(string(out)))
	var candidate struct {
		cardIdx int
		cardID  string
		dev     string
	}
	candidate.cardIdx = -1

	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "card ") {
			continue
		}
		cardIdx, cardID, dev, desc := parseAplayCardLine(line)
		if cardIdx < 0 {
			continue
		}
		lowDesc := strings.ToLower(desc)
		if strings.Contains(lowDesc, "hdmi") {
			continue
		}
		// Prefer a device whose description mentions analog output.
		if strings.Contains(lowDesc, "analog") {
			return fmt.Sprintf("plughw:CARD=%s,DEV=%s", cardID, dev)
		}
		if candidate.cardIdx < 0 {
			candidate.cardIdx = cardIdx
			candidate.cardID = cardID
			candidate.dev = dev
		}
	}

	if candidate.cardIdx >= 0 {
		return fmt.Sprintf("plughw:CARD=%s,DEV=%s", candidate.cardID, candidate.dev)
	}
	return ""
}

func parseAplayCardLine(line string) (cardIdx int, cardID, dev, desc string) {
	cardPart := line
	if i := strings.Index(line, "device "); i >= 0 {
		devicePart := line[i:]
		if di := strings.Index(devicePart, ":"); di >= 0 {
			desc = strings.TrimSpace(devicePart[di+1:])
			// desc is like "HDMI 0 [HDMI 0]" -> take text before '['
			if bi := strings.Index(desc, "["); bi >= 0 {
				desc = strings.TrimSpace(desc[:bi])
			}
		}
		// device index
		devField := devicePart[len("device "):]
		if di := strings.Index(devField, ":"); di >= 0 {
			dev = strings.TrimSpace(devField[:di])
		}
		cardPart = line[:i]
	}

	cp := strings.TrimSpace(strings.TrimPrefix(cardPart, "card"))
	if ci := strings.Index(cp, ":"); ci >= 0 {
		fmt.Sscanf(cp[:ci], "%d", &cardIdx)
		idPart := strings.TrimSpace(cp[ci+1:])
		if bi := strings.Index(idPart, "["); bi >= 0 {
			cardID = strings.TrimSpace(idPart[:bi])
		} else {
			cardID = idPart
		}
	}
	return
}
