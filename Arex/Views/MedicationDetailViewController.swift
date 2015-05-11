import ArexKit
import ReactiveCocoa
import UIKit
import XLForm

class MedicationDetailViewController: XLFormViewController {
    private struct Constants {
        struct CellIdentifiers {
            static let DefaultCell = "DefaultCell"
            static let RightDetailCell = "RightDetailCell"
            static let TextFieldCell = "TextFieldCell"
            static let SelectableCell = "SelectableCell"
            static let StepperCell = "StepperCell"
        }

        struct SegueIdentifiers {
            static let DismissModalEditor = "DismissModalEditor"
        }
    }

    private enum StepperTag: Int {
        case Integer = 1000
        case Date
    }

    var viewModel: MedicationDetailViewModel!

    private let disposable = CompositeDisposable()

    // MARK: Bar Button Items

    private enum BarButtonItem: Printable {
        case Edit
        case Save
        case Cancel

        var description: String {
            switch self {
            case .Edit: return "edit"
            case .Save: return "save"
            case .Cancel: return "cancel"
            }
        }

        var systemItem: UIBarButtonSystemItem {
            switch self {
            case .Edit: return .Edit
            case .Save: return .Save
            case .Cancel: return .Cancel
            }
        }
    }

    private func barButtonItem(type: BarButtonItem) -> UIBarButtonItem {
        precondition(viewModel != nil, "MedicationDetailViewController.viewModel was not assigned before \(type)BarButtonItem loaded")

        let action: CocoaAction
        let enabled: PropertyOf<Bool>

        switch type {
        case .Edit:
            action = CocoaAction(viewModel.beginEditing, void)
            enabled = viewModel.beginEditing.enabled
        case .Save:
            action = CocoaAction(viewModel.saveChanges, void)
            enabled = viewModel.saveChanges.enabled
        case .Cancel:
            action = CocoaAction(viewModel.revertChanges, void)
            enabled = viewModel.revertChanges.enabled
        }

        barButtonItemCocoaActions.insert(action)

        var barButtonItem = UIBarButtonItem(barButtonSystemItem: type.systemItem, target: action, action: CocoaAction.selector)
        enabled.producer.start(next: { [weak barButtonItem] enabled in
            barButtonItem?.enabled = enabled
        })
        return barButtonItem
    }

    private var barButtonItemCocoaActions = Set<CocoaAction>()
    private lazy var saveBarButtonItem: UIBarButtonItem = self.barButtonItem(.Save)
    private lazy var cancelBarButtonItem: UIBarButtonItem = self.barButtonItem(.Cancel)
    private lazy var editBarButtonItem: UIBarButtonItem = self.barButtonItem(.Edit)

    deinit {
        disposable.dispose()
    }

    private lazy var listItemNumberFormatter: NSNumberFormatter = {
        let numberFormatter = NSNumberFormatter()
        numberFormatter.formattingContext = .ListItem
        numberFormatter.locale = NSLocale.currentLocale()
        numberFormatter.numberStyle = .DecimalStyle
        return numberFormatter
    }()

    private lazy var standaloneNumberFormatter: NSNumberFormatter = {
        let numberFormatter = NSNumberFormatter()
        numberFormatter.formattingContext = .Standalone
        numberFormatter.locale = NSLocale.currentLocale()
        numberFormatter.numberStyle = .DecimalStyle
        return numberFormatter
    }()

    // MARK: - Calendar

    private let calendar = NSCalendar.currentCalendar()

    private func daysSinceReferenceDate(date: NSDate) -> Double {
        let components = calendar.components(.CalendarUnitDay, fromDate: NSDate(timeIntervalSinceReferenceDate: 0), toDate: date, options: nil)
        return Double(components.day)
    }

    private func date(daysSinceReferenceDate days: Double) -> NSDate {
        return calendar.dateByAddingUnit(.CalendarUnitDay, value: Int(days), toDate: NSDate(timeIntervalSinceReferenceDate: 0), options: nil) ?? undefined("Could not create NSDate instance with \(Int(days)) day(s) since reference date")
    }

    private lazy var dateFormatter: NSDateFormatter = {
        let dateFormatter = NSDateFormatter()
        dateFormatter.calendar = self.calendar
        dateFormatter.dateStyle = .MediumStyle
        dateFormatter.doesRelativeDateFormatting = true
        dateFormatter.formattingContext = .Standalone
        dateFormatter.locale = NSLocale.currentLocale()
        dateFormatter.timeStyle = .NoStyle
        return dateFormatter
    }()

    // MARK: - Configuration

    private func configureNavigationItem() {
        let property = map(viewModel.name) { name in
            return flush(name, not(isEmpty))
                ?? NSLocalizedString("New Medication", comment: "Medication detail view title if medication has empty name")
        }

        disposable += property.producer.start(next: { [unowned self] title in
            self.navigationItem.title = title
        })
    }

    private func configureTableView() {
        form = viewModel.formDescriptor()
    }

    private func configureEditing() {
        updateUI(editing)

        let beginEditing = viewModel.beginEditing.executing.producer
            |> skip(1)
            |> filter(!)
            |> map(replace(true))
        let saveChanges = viewModel.saveChanges.executing.producer
            |> skip(1)
            |> filter(!)
            |> map(replace(false))
        disposable += SignalProducer(values: [beginEditing, saveChanges])
            |> flatten(.Merge)
            |> start(next: { [unowned self] editing in
                self.setEditing(editing, animated: true)
            })
        disposable += viewModel.revertChanges.executing.producer
            |> skip(1)
            |> start(next: { [unowned self] reverting in
                if reverting {
                    self.tableView.beginUpdates()
                    self.setEditing(false, animated: false)
                } else {
                    self.tableView.reloadData()
                    self.tableView.endUpdates()
                }
            })
    }

    // MARK: - UI Update

    private func updateUI(editing: Bool) {
        updateNavigationItem(editing)
    }

    private func updateNavigationItem(editing: Bool) {
        let rightBarButtonItem, leftBarButtonItem: UIBarButtonItem?

        if editing {
            rightBarButtonItem = saveBarButtonItem
            leftBarButtonItem = cancelBarButtonItem
        } else {
            rightBarButtonItem = editBarButtonItem
            leftBarButtonItem = nil
        }

        let animated = true
        navigationItem.setRightBarButtonItem(rightBarButtonItem, animated: animated)
        navigationItem.setLeftBarButtonItem(leftBarButtonItem, animated: animated)
    }

    // MARK: - View Life Cycle

    override func setEditing(editing: Bool, animated: Bool) {
        if !editing && viewModel.isNew {
            dismissViewControllerAnimated(true, completion: nil)
            return
        }

        if !editing {
            view.endEditing(true)
        }

        tableView.beginUpdates()

        super.setEditing(editing, animated: animated)
        updateUI(editing)

        tableView.endUpdates()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // `precondition` the view model
        precondition(viewModel != nil, "viewModel was not assigned before MedicationDetailViewController.viewDidLoad()")

        configureNavigationItem()
        configureTableView()
        configureEditing()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        if !editing && !viewModel.editing.value {
            navigationItem.rightBarButtonItem = editBarButtonItem
        }
    }
}
