(eval-when-compile (require 'cl))
(require 'ert)

(require 'ein-notebook)


(defvar eintest:notebook-data-simple-json
  "{
 \"metadata\": {
  \"name\": \"Untitled0\"
 },
 \"name\": \"Untitled0\",
 \"nbformat\": 2,
 \"worksheets\": [
  {
   \"cells\": [
    {
     \"cell_type\": \"code\",
     \"collapsed\": false,
     \"input\": \"1 + 1\",
     \"language\": \"python\",
     \"outputs\": [
      {
       \"output_type\": \"pyout\",
       \"prompt_number\": 1,
       \"text\": \"2\"
      }
     ],
     \"prompt_number\": 1
    }
   ]
  }
 ]
}
")


(defun eintest:notebook-from-json (json-string &optional notebook-id)
  (unless notebook-id (setq notebook-id "NOTEBOOK-ID"))
  (with-temp-buffer
    (erase-buffer)
    (insert json-string)
    (flet ((pop-to-buffer (buf) buf)
           (ein:notebook-start-kernel ()))
      (ein:notebook-url-retrieve-callback
       nil
       (ein:notebook-new "DUMMY-URL" notebook-id)))))

(defun eintest:notebook-make-data (cells &optional name)
  (unless name (setq name "Dummy Name"))
  `((metadata . ((name . ,name)))
    (name . ,name)
    (worksheets . [((cells . ,(apply #'vector cells)))])))

(defun eintest:notebook-make-empty ()
  "Make empty notebook and return its buffer."
  (eintest:notebook-from-json
   (json-encode (eintest:notebook-make-data nil))))

(ert-deftest ein:notebook-from-json-simple ()
  (with-current-buffer (eintest:notebook-from-json
                        eintest:notebook-data-simple-json)
    (should (ein:$notebook-p ein:notebook))
    (should (equal (ein:$notebook-notebook-id ein:notebook) "NOTEBOOK-ID"))
    (should (equal (ein:$notebook-notebook-name ein:notebook) "Untitled0"))
    (should (equal (ein:notebook-ncells ein:notebook) 1))
    (let ((cell (car (ein:notebook-get-cells ein:notebook))))
      (should (ein:codecell-p cell))
      (should (equal (oref cell :input) "1 + 1"))
      (should (equal (oref cell :input-prompt-number) 1))
      (let ((outputs (oref cell :outputs)))
        (should (equal (length outputs) 1))
        (let ((o1 (car outputs)))
          (should (equal (plist-get o1 :output_type) "pyout"))
          (should (equal (plist-get o1 :prompt_number) 1))
          (should (equal (plist-get o1 :text) "2")))))))

(ert-deftest ein:notebook-from-json-empty ()
  (with-current-buffer (eintest:notebook-make-empty)
    (should (ein:$notebook-p ein:notebook))
    (should (equal (ein:$notebook-notebook-id ein:notebook) "NOTEBOOK-ID"))
    (should (equal (ein:$notebook-notebook-name ein:notebook) "Dummy Name"))
    (should (equal (ein:notebook-ncells ein:notebook) 0))))

(ert-deftest ein:notebook-insert-cell-below-command-simple ()
  (with-current-buffer (eintest:notebook-make-empty)
    (ein:notebook-insert-cell-below-command)
    (ein:notebook-insert-cell-below-command)
    (ein:notebook-insert-cell-below-command)
    (should (equal (ein:notebook-ncells ein:notebook) 3))))

(ert-deftest ein:notebook-insert-cell-above-command-simple ()
  (with-current-buffer (eintest:notebook-make-empty)
    (ein:notebook-insert-cell-above-command)
    (ein:notebook-insert-cell-above-command)
    (ein:notebook-insert-cell-above-command)
    (should (equal (ein:notebook-ncells ein:notebook) 3))))

(ert-deftest ein:notebook-delete-cell-command-simple ()
  (with-current-buffer (eintest:notebook-make-empty)
    (loop repeat 3
          do (ein:notebook-insert-cell-above-command))
    (should (equal (ein:notebook-ncells ein:notebook) 3))
    (loop repeat 3
          do (ein:notebook-delete-cell-command))
    (should (equal (ein:notebook-ncells ein:notebook) 0))))

(ert-deftest ein:notebook-kill-cell-command-simple ()
  (with-current-buffer (eintest:notebook-make-empty)
    (let (ein:kill-ring ein:kill-ring-yank-pointer)
      (loop repeat 3
            do (ein:notebook-insert-cell-above-command))
      (should (equal (ein:notebook-ncells ein:notebook) 3))
      (loop for i from 1 to 3
            do (ein:notebook-kill-cell-command)
            do (should (equal (length ein:kill-ring) i))
            do (should (equal (ein:notebook-ncells ein:notebook) (- 3 i)))))))

(ert-deftest ein:notebook-copy-cell-command-simple ()
  (with-current-buffer (eintest:notebook-make-empty)
    (let (ein:kill-ring ein:kill-ring-yank-pointer)
      (loop repeat 3
            do (ein:notebook-insert-cell-above-command))
      (should (equal (ein:notebook-ncells ein:notebook) 3))
      (loop repeat 3
            do (ein:notebook-copy-cell-command))
      (should (equal (ein:notebook-ncells ein:notebook) 3))
      (should (equal (length ein:kill-ring) 3)))))


;; Misc unit tests

(ert-deftest ein:notebook-test-notebook-name-simple ()
  (should-not (ein:notebook-test-notebook-name nil))
  (should-not (ein:notebook-test-notebook-name ""))
  (should-not (ein:notebook-test-notebook-name "/"))
  (should-not (ein:notebook-test-notebook-name "\\"))
  (should-not (ein:notebook-test-notebook-name "a/b"))
  (should-not (ein:notebook-test-notebook-name "a\\b"))
  (should (ein:notebook-test-notebook-name "This is a OK notebook name")))

(ert-deftest ein:notebook-console-security-dir-string ()
  (let ((ein:notebook-console-security-dir "/some/dir/")
        (notebook (ein:notebook-new "DUMMY-URL-OR-PORT" "DUMMY-NOTEBOOK-ID")))
    (should (equal (ein:notebook-console-security-dir-get notebook)
                   ein:notebook-console-security-dir))))

(ert-deftest ein:notebook-console-security-dir-list ()
  (let ((ein:notebook-console-security-dir
         '((8888 . "/dir/8888/")
           ("htttp://dummy.org" . "/dir/http/")
           (default . "/dir/default/"))))
    (let ((notebook (ein:notebook-new 8888 "DUMMY-NOTEBOOK-ID")))
      (should (equal (ein:notebook-console-security-dir-get notebook)
                     "/dir/8888/")))
    (let ((notebook (ein:notebook-new "htttp://dummy.org" "DUMMY-NOTEBOOK-ID")))
      (should (equal (ein:notebook-console-security-dir-get notebook)
                     "/dir/http/")))
    (let ((notebook (ein:notebook-new 9999 "DUMMY-NOTEBOOK-ID")))
      (should (equal (ein:notebook-console-security-dir-get notebook)
                     "/dir/default/")))))

(ert-deftest ein:notebook-console-security-dir-func ()
  (let ((ein:notebook-console-security-dir
         '(lambda (x) (should (equal x "DUMMY-URL-OR-PORT")) "/dir/"))
        (notebook (ein:notebook-new "DUMMY-URL-OR-PORT" "DUMMY-NOTEBOOK-ID")))
    (should (equal (ein:notebook-console-security-dir-get notebook) "/dir/"))))
