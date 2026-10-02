package obfuscateme;

import java.io.File;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

/**
 * Resolves external Android tooling independently of the process working
 * directory. This makes packaged builds work when started from Explorer,
 * shortcuts, IDEs, or a terminal in another directory.
 */
final class ToolLocator {

    private ToolLocator() {
    }

    static String require(String fileName) {
        List<Path> candidates = new ArrayList<>();

        Path workingDirectory = Paths.get(System.getProperty("user.dir", ".")).toAbsolutePath();
        candidates.add(workingDirectory.resolve("lib").resolve(fileName));
        candidates.add(workingDirectory.resolve("dist").resolve("lib").resolve(fileName));
        candidates.add(workingDirectory.resolve("exe").resolve("lib").resolve(fileName));

        try {
            Path codeLocation = Paths.get(
                    ToolLocator.class.getProtectionDomain()
                            .getCodeSource()
                            .getLocation()
                            .toURI()
            ).toAbsolutePath();

            Path appDirectory = Files.isDirectory(codeLocation)
                    ? codeLocation
                    : codeLocation.getParent();

            if (appDirectory != null) {
                candidates.add(appDirectory.resolve("lib").resolve(fileName));

                Path parent = appDirectory.getParent();
                if (parent != null) {
                    candidates.add(parent.resolve("lib").resolve(fileName));
                }
            }
        } catch (URISyntaxException | NullPointerException ignored) {
            // Fall back to working-directory candidates below.
        }

        for (Path candidate : candidates) {
            if (Files.isRegularFile(candidate)) {
                return candidate.normalize().toString();
            }
        }

        StringBuilder message = new StringBuilder(
                "Required Android tool not found: " + fileName + System.lineSeparator()
                + "Run scripts/update-tools.ps1 (Windows) or scripts/update-tools.sh first."
                + System.lineSeparator()
                + "Searched:"
        );

        for (Path candidate : candidates) {
            message.append(System.lineSeparator()).append(" - ").append(candidate.normalize());
        }

        throw new IllegalStateException(message.toString());
    }
}
