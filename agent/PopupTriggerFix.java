package macfix;

import java.awt.AWTEvent;
import java.awt.Image;
import java.awt.Toolkit;
import java.awt.event.AWTEventListener;
import java.awt.event.InputEvent;
import java.awt.event.MouseEvent;
import java.io.File;
import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;

/**
 * Java agent for SAP MII Workbench on macOS.
 *
 * 1. Right-click: on macOS, MouseEvent.isPopupTrigger() is true on MOUSE_PRESSED; on
 *    Windows it is true on MOUSE_RELEASED. The Workbench only opens its tree context
 *    menu on a released popup trigger, so on a Mac right-click does nothing. This moves
 *    the flag from press to release before any component sees the event.
 * 2. Dock: shows the JVM as "MII Workbench" with the icon passed as the agent argument
 *    (-javaagent:mac-popup-fix.jar=/path/to/icon.png) instead of a generic "java".
 *
 * Everything privileged happens in premain, before IcedTea-Web installs its
 * SecurityManager; afterwards the listener only writes an already-accessible field.
 */
public final class PopupTriggerFix implements AWTEventListener {
    private static Field popupTrigger;

    public static void premain(String args, Instrumentation inst) {
        if (!System.getProperty("os.name", "").toLowerCase().contains("mac")) return;
        // must be set before AWT starts; ignored by a JVM hidden with apple.awt.UIElement
        System.setProperty("apple.awt.application.name", "MII Workbench");
        try {
            popupTrigger = MouseEvent.class.getDeclaredField("popupTrigger");
            popupTrigger.setAccessible(true);
            Toolkit.getDefaultToolkit().addAWTEventListener(new PopupTriggerFix(), AWTEvent.MOUSE_EVENT_MASK);
        } catch (Throwable t) {
            System.err.println("[mac-popup-fix] right-click fix disabled: " + t);
        }
        if (args != null && new File(args).isFile() && !Boolean.getBoolean("apple.awt.UIElement")) {
            setDockIcon(Toolkit.getDefaultToolkit().getImage(args));
        }
    }

    // com.apple.eawt on Java 8, java.awt.Taskbar on Java 9+; reflection keeps one jar for both
    private static void setDockIcon(Image icon) {
        try {
            Class<?> taskbar = Class.forName("java.awt.Taskbar");
            Object tb = taskbar.getMethod("getTaskbar").invoke(null);
            taskbar.getMethod("setIconImage", Image.class).invoke(tb, icon);
            return;
        } catch (Throwable ignored) {
        }
        try {
            Class<?> app = Class.forName("com.apple.eawt.Application");
            Object a = app.getMethod("getApplication").invoke(null);
            app.getMethod("setDockIconImage", Image.class).invoke(a, icon);
        } catch (Throwable t) {
            System.err.println("[mac-popup-fix] dock icon not set: " + t);
        }
    }

    @Override
    public void eventDispatched(AWTEvent event) {
        if (!(event instanceof MouseEvent)) return;
        MouseEvent e = (MouseEvent) event;
        boolean secondary = e.getButton() == MouseEvent.BUTTON3
                || (e.getButton() == MouseEvent.BUTTON1 && (e.getModifiersEx() & InputEvent.CTRL_DOWN_MASK) != 0);
        if (!secondary) return;
        try {
            if (e.getID() == MouseEvent.MOUSE_PRESSED) popupTrigger.setBoolean(e, false);
            else if (e.getID() == MouseEvent.MOUSE_RELEASED) popupTrigger.setBoolean(e, true);
        } catch (IllegalAccessException ignored) {
        }
    }
}
